package user

import (
	"context"
	"errors"
	"fmt"

	"siagakita-backend/internal/config"
	"siagakita-backend/internal/domain/otp"
	"siagakita-backend/internal/utils"

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
	if _, err := s.repo.FindByEmail(req.Email); err == nil {
		return nil, errors.New("email sudah terdaftar")
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
		return nil, errors.New("akun ini tidak memiliki akses ke console")
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
		return nil, errors.New("akun ini bukan akun personel instansi")
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
