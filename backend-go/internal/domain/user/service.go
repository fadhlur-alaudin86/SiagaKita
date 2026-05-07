package user

import (
	"context"
	"errors"
	"fmt"
	"path/filepath"

	"siagakita-backend/internal/config"
	"siagakita-backend/internal/domain/otp"
	"siagakita-backend/internal/utils"

	"github.com/gofiber/fiber/v2"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// Service contains the business logic for the user domain.
type Service struct {
	repo   *Repository
	cfg    *config.Config
	otpSvc otp.Service
}

// NewService creates a new user Service.
func NewService(repo *Repository, cfg *config.Config, otpSvc otp.Service) *Service {
	return &Service{repo: repo, cfg: cfg, otpSvc: otpSvc}
}

// ─── Register (civilian/volunteer via mobile) ─────────────────────────────────

// RegisterResult dikembalikan oleh Register — tidak mengandung JWT karena
// pengguna harus verifikasi email terlebih dahulu.
type RegisterResult struct {
	Message string `json:"message"`
	Email   string `json:"email"`
}

// Register membuat akun civilian baru + row user_profiles dalam satu transaksi.
// OTP email dikirim SETELAH transaksi DB berhasil.
// Jika SMTP gagal → hard-delete user (CASCADE menghapus user_profiles otomatis).
func (s *Service) Register(ctx context.Context, req *RegisterRequest) (*RegisterResult, error) {
	if req.FullName == "" || req.Email == "" || req.Password == "" {
		return nil, errors.New("full_name, email, dan password wajib diisi")
	}
	if len(req.Password) < 8 {
		return nil, errors.New("password minimal 8 karakter")
	}

	// Cek duplikasi email
	existingUser, err := s.repo.FindByEmail(req.Email)
	if err == nil {
		// Jika email ada tapi BELUM verified (karena timeout OTP sebelumnya), hapus yang lama
		profile, _ := s.repo.FindProfile(existingUser.ID)
		if profile != nil && !profile.IsEmailVerified {
			_ = s.repo.DeleteUserByEmail(req.Email)
		} else {
			return nil, errors.New("email sudah terdaftar")
		}
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
	if err != nil {
		return nil, err
	}

	// Transaksi atomik: buat users + user_profiles sekaligus.
	// Jika salah satu gagal, keduanya di-rollback — tidak ada orphaned row.
	user := &User{
		Email:        req.Email,
		PasswordHash: string(hash),
		Role:         "civilian",
	}
	profile := &UserProfile{
		FullName: &req.FullName,
	}
	if err := s.repo.CreateUserWithProfile(user, profile); err != nil {
		return nil, fmt.Errorf("gagal membuat akun: %w", err)
	}

	// Kirim OTP ke email SETELAH transaksi DB commit.
	// Jika gagal → hard-delete user (ON DELETE CASCADE menghapus user_profiles).
	if err := s.otpSvc.RequestEmailOTP(ctx, req.Email, "register"); err != nil {
		_ = s.repo.DeleteUserByEmail(req.Email) // cascade delete user_profiles
		return nil, fmt.Errorf("gagal mengirim OTP ke email: %w", err)
	}

	return &RegisterResult{
		Message: "Akun berhasil dibuat. Masukkan kode OTP yang telah dikirimkan ke email Anda.",
		Email:   req.Email,
	}, nil
}

// ─── VerifyRegisterOTP ────────────────────────────────────────────────────────

func (s *Service) VerifyRegisterOTP(ctx context.Context, email, code string) (*AuthResponse, error) {
	if err := s.otpSvc.VerifyEmailOTP(ctx, email, "register", code); err != nil {
		return nil, err
	}
	user, err := s.repo.FindByEmail(email)
	if err != nil {
		return nil, errors.New("akun tidak ditemukan")
	}
	if err := s.repo.SetEmailVerified(user.ID); err != nil {
		return nil, err
	}
	profile, _ := s.repo.FindProfile(user.ID)
	return s.buildAuthResponse(user, profile)
}

// ─── Login (mobile: civilian/volunteer) ──────────────────────────────────────

// Login memvalidasi email + password dan menerbitkan JWT.
// Hanya mengizinkan role civilian dan volunteer.
func (s *Service) Login(ctx context.Context, req *LoginRequest) (*AuthResponse, error) {
	user, err := s.repo.FindByEmail(req.Email)
	if err != nil {
		return nil, errors.New("email atau password salah")
	}
	if user.Role != "civilian" && user.Role != "volunteer" {
		return nil, errors.New("email atau password salah")
	}
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		return nil, errors.New("email atau password salah")
	}
	profile, _ := s.repo.FindProfile(user.ID)

	// Tolak login jika email belum diverifikasi (mencegah ghost account login)
	if profile != nil && !profile.IsEmailVerified {
		return nil, errors.New("email belum diverifikasi, silakan daftar ulang")
	}

	return s.buildAuthResponse(user, profile)
}

// ─── Console Login (admin/superadmin/agency) ─────────────────────────────────

// ConsoleLogin hanya mengizinkan role superadmin, admin, dan agency.
func (s *Service) ConsoleLogin(ctx context.Context, req *LoginRequest) (*AuthResponse, error) {
	user, err := s.repo.FindByEmail(req.Email)
	if err != nil {
		return nil, errors.New("email atau password salah")
	}

	allowedRoles := map[string]bool{"superadmin": true, "admin": true, "agency": true}
	if !allowedRoles[user.Role] {
		// Gunakan pesan generic agar tidak membocorkan role/keberadaan akun
		return nil, errors.New("email atau password salah")
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		return nil, errors.New("email atau password salah")
	}

	// Ambil full_name dari admin_profiles jika ada
	var fullName *string
	if user.Role == "admin" || user.Role == "superadmin" {
		var ap AdminProfile
		if err := s.repo.db.Where("user_id = ?", user.ID).First(&ap).Error; err == nil {
			fullName = ap.FullName
		}
	}
	// Untuk agency, nama ada di tabel agencies — dikembalikan via agencies endpoint

	return s.buildAuthResponseWithName(user, fullName)
}

// ─── Personnel Login (agency_personnel via mobile responder) ─────────────────

// PersonnelLogin hanya mengizinkan role agency_personnel.
func (s *Service) PersonnelLogin(ctx context.Context, req *LoginRequest) (*AuthResponse, error) {
	user, err := s.repo.FindByEmail(req.Email)
	if err != nil {
		return nil, errors.New("email atau password salah")
	}
	if user.Role != "agency_personnel" {
		return nil, errors.New("email atau password salah")
	}
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		return nil, errors.New("email atau password salah")
	}

	// Ambil full_name dari agency_personnels
	var fullName *string
	personnel, err := s.repo.FindPersonnelByUserID(user.ID)
	if err == nil {
		fullName = &personnel.FullName
	}

	return s.buildAuthResponseWithName(user, fullName)
}

// ─── VerifyLoginOTP ───────────────────────────────────────────────────────────

func (s *Service) VerifyLoginOTP(ctx context.Context, email, code string) (*AuthResponse, error) {
	if err := s.otpSvc.VerifyEmailOTP(ctx, email, "login", code); err != nil {
		return nil, err
	}
	user, err := s.repo.FindByEmail(email)
	if err != nil {
		return nil, errors.New("akun tidak ditemukan")
	}
	profile, _ := s.repo.FindProfile(user.ID)
	return s.buildAuthResponse(user, profile)
}

// ─── Phone Verification ───────────────────────────────────────────────────────

func (s *Service) RequestPhoneVerification(ctx context.Context, userID, phone string) error {
	if err := s.repo.UpdatePhoneNumber(userID, phone); err != nil {
		return err
	}
	return s.otpSvc.RequestOTP(ctx, phone)
}

func (s *Service) ConfirmPhoneOTP(ctx context.Context, userID, phone, code string) error {
	if err := s.otpSvc.VerifyOTP(ctx, phone, code); err != nil {
		return err
	}
	return s.repo.SetPhoneVerified(userID)
}

// ─── Profile ──────────────────────────────────────────────────────────────────

func (s *Service) SaveBiodata(userID string, req *BiodataRequest) error {
	return s.repo.SaveBiodata(userID, req)
}

func (s *Service) GetProfile(userID string) (*ProfileResponse, error) {
	return s.repo.GetProfile(userID)
}

func (s *Service) UpdateProfile(userID string, req *UpdateProfileRequest) error {
	return s.repo.UpdateProfile(userID, req)
}

// ─── Token builders ───────────────────────────────────────────────────────────

// buildAuthResponse digunakan untuk civilian/volunteer (nama dari user_profiles).
func (s *Service) buildAuthResponse(user *User, profile *UserProfile) (*AuthResponse, error) {
	var fullName *string
	if profile != nil {
		fullName = profile.FullName
	}
	return s.buildAuthResponseWithName(user, fullName)
}

func (s *Service) buildAuthResponseWithName(user *User, fullName *string) (*AuthResponse, error) {
	accessToken, err := utils.GenerateAccessToken(user.ID, user.Role, s.cfg.JWTSecret, s.cfg.JWTAccessTTL)
	if err != nil {
		return nil, err
	}
	refreshToken, err := utils.GenerateRefreshToken(user.ID, user.Role, s.cfg.JWTSecret, s.cfg.JWTRefreshTTL)
	if err != nil {
		return nil, err
	}

	return &AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		User: UserInfo{
			ID:       user.ID,
			Email:    user.Email,
			Role:     user.Role,
			FullName: fullName,
		},
	}, nil
}

// ─── Forgot Password & Resend OTP ─────────────────────────────────────────────

func (s *Service) ForgotPassword(ctx context.Context, email string) error {
	_, err := s.repo.FindByEmail(email)
	if err != nil {
		return errors.New("akun tidak ditemukan")
	}
	return s.otpSvc.RequestEmailOTP(ctx, email, "forgot_password")
}

func (s *Service) ResetPassword(ctx context.Context, email, otp, newPassword string) error {
	if len(newPassword) < 8 {
		return errors.New("password minimal 8 karakter")
	}
	if err := s.otpSvc.VerifyEmailOTP(ctx, email, "forgot_password", otp); err != nil {
		return err
	}
	user, err := s.repo.FindByEmail(email)
	if err != nil {
		return errors.New("akun tidak ditemukan")
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(newPassword), 12)
	if err != nil {
		return err
	}
	return s.repo.UpdatePassword(user.ID, string(hash))
}

func (s *Service) ResendOTP(ctx context.Context, email, otpContext string) error {
	_, err := s.repo.FindByEmail(email)
	if err != nil {
		return errors.New("akun tidak ditemukan")
	}
	return s.otpSvc.RequestEmailOTP(ctx, email, otpContext)
}

// ─── KYC Warga ────────────────────────────────────────────────────────────────

// SubmitKYC memproses pengajuan verifikasi NIK warga: upload foto KTP & selfie,
// lalu simpan URL dan set status menjadi 'pending'.
func (s *Service) SubmitKYC(c *fiber.Ctx, userID, nik, fullName string) error {
	uploadDir := s.cfg.UploadDir + "/kyc"

	// Upload foto KTP
	ktpFile, err := c.FormFile("ktp")
	if err != nil {
		return errors.New("foto KTP wajib dilampirkan")
	}
	ktpExt := filepath.Ext(ktpFile.Filename)
	ktpPath := uploadDir + "/" + userID + "_ktp" + ktpExt
	if err := c.SaveFile(ktpFile, "."+ktpPath); err != nil {
		return fmt.Errorf("gagal menyimpan foto KTP: %w", err)
	}

	// Upload selfie (opsional tapi direkomendasikan)
	selfieURL := ""
	selfieFile, err := c.FormFile("selfie")
	if err == nil {
		selfieExt := filepath.Ext(selfieFile.Filename)
		selfiePath := uploadDir + "/" + userID + "_selfie" + selfieExt
		if err := c.SaveFile(selfieFile, "."+selfiePath); err != nil {
			return fmt.Errorf("gagal menyimpan selfie: %w", err)
		}
		selfieURL = selfiePath
	}

	return s.repo.SubmitKYC(userID, nik, fullName, ktpPath, selfieURL)
}

// GetKYCStatus mengembalikan status verifikasi NIK warga.
func (s *Service) GetKYCStatus(userID string) (*KYCStatusResponse, error) {
	profile, err := s.repo.GetKYCStatus(userID)
	if err != nil {
		return nil, err
	}
	msg := map[string]string{
		"none":     "Anda belum mengajukan verifikasi NIK.",
		"pending":  "Pengajuan sedang diproses oleh admin (1-3 hari kerja).",
		"approved": "Identitas Anda telah terverifikasi ✅",
		"rejected": "Pengajuan ditolak. Silakan ajukan ulang dengan foto yang lebih jelas.",
	}[profile.NIKVerificationStatus]
	return &KYCStatusResponse{
		Status:  KYCStatus(profile.NIKVerificationStatus),
		NIK:     profile.NIK,
		Message: msg,
	}, nil
}
