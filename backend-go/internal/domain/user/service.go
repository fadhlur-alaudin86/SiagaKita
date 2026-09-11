package user

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"siagakita-backend/internal/config"
	"siagakita-backend/internal/domain/otp"
	"siagakita-backend/internal/hub"
	"siagakita-backend/internal/utils"

	"github.com/bytedance/sonic"
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// Service contains the business logic for the user domain.
type Service struct {
	repo   *Repository
	cfg    *config.Config
	otpSvc otp.Service
	rdb    *redis.Client
	hub    *hub.Hub
}

// NewService creates a new user Service.
func NewService(repo *Repository, cfg *config.Config, otpSvc otp.Service, rdb *redis.Client, h *hub.Hub) *Service {
	return &Service{repo: repo, cfg: cfg, otpSvc: otpSvc, rdb: rdb, hub: h}
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
		Role:         RoleCivilian,
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
	if user.Role != RoleCivilian && user.Role != RoleVolunteer {
		return nil, errors.New("email atau password salah")
	}
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		return nil, errors.New("email atau password salah")
	}
	profile, _ := s.repo.FindProfile(user.ID)

	// Tolak login jika email belum diverifikasi (mencegah ghost account login)
	if profile != nil && !profile.IsEmailVerified {
		return nil, errors.New("email atau password salah")
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

	allowedRoles := map[string]bool{RoleSuperAdmin: true, RoleAdmin: true, RoleAgency: true}
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

// PersonnelLogin mengizinkan role agency_personnel login dengan email atau badge_number.
func (s *Service) PersonnelLogin(ctx context.Context, req *LoginRequest) (*AuthResponse, error) {
	identifier := strings.TrimSpace(req.Email)
	if identifier == "" || req.Password == "" {
		return nil, errors.New("email atau password salah")
	}

	var user *User
	var fullName *string
	var badgeNumber *string

	if strings.Contains(identifier, "@") {
		u, err := s.repo.FindByEmail(identifier)
		if err != nil {
			return nil, errors.New("email atau password salah")
		}
		user = u
		personnel, err := s.repo.FindPersonnelByUserID(user.ID)
		if err == nil {
			fullName = &personnel.FullName
			badgeNumber = &personnel.BadgeNumber
		}
	} else {
		personnel, err := s.repo.FindPersonnelByBadgeNumber(identifier)
		if err != nil {
			return nil, errors.New("email atau password salah")
		}
		u, err := s.repo.FindByID(personnel.UserID)
		if err != nil {
			return nil, errors.New("email atau password salah")
		}
		user = u
		fullName = &personnel.FullName
		badgeNumber = &personnel.BadgeNumber
	}

	if user.Role != "agency_personnel" {
		return nil, errors.New("email atau password salah")
	}
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		return nil, errors.New("email atau password salah")
	}

	return s.buildAuthResponseWithName(user, fullName, badgeNumber)
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
	if req.PlaceOfBirth != nil && len(*req.PlaceOfBirth) > 100 {
		return errors.New("tempat lahir maksimal 100 karakter")
	}
	if req.Allergies != nil && len(*req.Allergies) > 255 {
		return errors.New("alergi maksimal 255 karakter")
	}
	if req.MedicalConditions != nil && len(*req.MedicalConditions) > 255 {
		return errors.New("kondisi medis maksimal 255 karakter")
	}
	if req.Domicile != nil && len(*req.Domicile) > 255 {
		return errors.New("domisili maksimal 255 karakter")
	}
	return s.repo.SaveBiodata(userID, req)
}

func (s *Service) GetProfile(userID string) (*ProfileResponse, error) {
	return s.repo.GetProfile(userID)
}

func (s *Service) UpdateProfile(userID string, req *UpdateProfileRequest) error {
	if req.FullName != nil && len(*req.FullName) > 100 {
		return errors.New("nama lengkap maksimal 100 karakter")
	}
	if req.PlaceOfBirth != nil && len(*req.PlaceOfBirth) > 100 {
		return errors.New("tempat lahir maksimal 100 karakter")
	}
	if req.Bio != nil && len(*req.Bio) > 255 {
		return errors.New("bio maksimal 255 karakter")
	}
	if req.Allergies != nil && len(*req.Allergies) > 255 {
		return errors.New("alergi maksimal 255 karakter")
	}
	if req.MedicalConditions != nil && len(*req.MedicalConditions) > 255 {
		return errors.New("kondisi medis maksimal 255 karakter")
	}
	if req.Domicile != nil && len(*req.Domicile) > 255 {
		return errors.New("domisili maksimal 255 karakter")
	}
	return s.repo.UpdateProfile(userID, req)
}

// ─── Pendaftaran Relawan ──────────────────────────────────────────────────────

func (s *Service) SubmitVolunteerRegistration(c *fiber.Ctx, userID string, experience string, specializations []string) error {
	saveDir := s.cfg.UploadDir + "/certificates"
	if err := os.MkdirAll(saveDir, 0750); err != nil {
		return fmt.Errorf("gagal membuat folder upload: %w", err)
	}

	form, err := c.MultipartForm()
	if err != nil {
		return errors.New("gagal membaca form data")
	}

	files := form.File["certificates"] // array of files
	if len(files) == 0 {
		return errors.New("sertifikat wajib dilampirkan")
	}

	// Baca tipe sertifikat per-file yang dikirim mobile (urutan sama dengan files)
	var certTypes []string
	if rawTypes := form.Value["cert_types"]; len(rawTypes) > 0 && rawTypes[0] != "" {
		for _, t := range strings.Split(rawTypes[0], ",") {
			certTypes = append(certTypes, strings.TrimSpace(t))
		}
	}

	var certs []map[string]string
	for i, file := range files {
		ext := filepath.Ext(file.Filename)
		id := uuid.New().String()
		savePath := saveDir + "/" + id + ext
		if err := c.SaveFile(file, savePath); err != nil {
			return fmt.Errorf("gagal menyimpan sertifikat: %w", err)
		}
		publicURL := s.cfg.UploadBaseURL + "/certificates/" + id + ext

		// Gunakan nama spesialisasi sebagai tipe sertifikat
		certType := "Sertifikat"
		if i < len(certTypes) && certTypes[i] != "" {
			certType = certTypes[i]
		}

		certs = append(certs, map[string]string{
			"type": certType,
			"url":  publicURL,
		})
	}

	// Gabungkan specializations ke dalam experience jika ada
	if len(specializations) > 0 {
		specsStr := strings.Join(specializations, ", ")
		experience = "Spesialisasi: " + specsStr + "\nPengalaman: " + experience
	}

	if len(experience) > 1000 {
		return errors.New("pengalaman dan spesialisasi terlalu panjang (maksimal 1000 karakter)")
	}

	return s.repo.SubmitVolunteerRegistration(userID, experience, certs)
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

func (s *Service) buildAuthResponseWithName(user *User, fullName *string, badgeNumber ...*string) (*AuthResponse, error) {
	accessToken, jti, err := utils.GenerateAccessToken(user.ID, user.Role, s.cfg.JWTSecret, s.cfg.JWTAccessTTL)
	if err != nil {
		return nil, err
	}
	refreshToken, refreshJTI, err := utils.GenerateRefreshToken(user.ID, user.Role, s.cfg.JWTSecret, s.cfg.JWTRefreshTTL)
	if err != nil {
		return nil, err
	}

	// ── Session & Refresh Token tracking di Redis ──────────────────────────────
	if s.rdb != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()

		if user.Role == RoleCivilian || user.Role == RoleVolunteer || user.Role == "agency_personnel" {
			sessionKey := "session:" + user.ID
			refreshKey := "refresh_token:" + user.ID

			// Kirim FORCE_LOGOUT ke koneksi WS lama (jika masih online)
			if s.hub != nil && s.hub.IsOnline(user.ID) {
				_ = s.hub.SendToUser(user.ID, hub.Message{
					Event: "FORCE_LOGOUT",
					Payload: map[string]string{
						"reason":     "session_replaced",
						fieldMessage: "Akun ini telah login di perangkat lain. Anda telah dikeluarkan.",
					},
				})
			}

			// Simpan JTI baru ke Redis (menggantikan session lama)
			_ = s.rdb.Set(ctx, sessionKey, jti, s.cfg.JWTAccessTTL)
			_ = s.rdb.Set(ctx, refreshKey, refreshJTI, s.cfg.JWTRefreshTTL)
		} else {
			// Console roles: per-JTI tracking (multi-device support)
			_ = s.rdb.Set(ctx, "refresh_jti:"+refreshJTI, "valid", s.cfg.JWTRefreshTTL)
		}
	}

	var badge *string
	if len(badgeNumber) > 0 {
		badge = badgeNumber[0]
	}

	return &AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		User: UserInfo{
			ID:          user.ID,
			Email:       user.Email,
			Role:        user.Role,
			FullName:    fullName,
			BadgeNumber: badge,
		},
	}, nil
}

func (s *Service) parseRefreshTokenClaims(refreshTokenStr string) (*utils.Claims, error) {
	if refreshTokenStr == "" {
		return nil, errors.New("refresh_token wajib diisi")
	}

	claims, err := utils.ParseToken(refreshTokenStr, s.cfg.JWTSecret)
	if err != nil {
		return nil, errors.New("token refresh tidak valid atau sudah kedaluwarsa")
	}

	if claims.TokenType != "refresh" {
		return nil, errors.New("tipe token tidak valid")
	}

	return claims, nil
}

func (s *Service) checkGracePeriod(ctx context.Context, graceKey string) (*AuthResponse, bool) {
	if s.rdb == nil {
		return nil, false
	}
	cachedJSON, err := s.rdb.Get(ctx, graceKey).Result()
	if err != nil || cachedJSON == "" {
		return nil, false
	}
	var cachedResp AuthResponse
	if err := sonic.Unmarshal([]byte(cachedJSON), &cachedResp); err == nil {
		return &cachedResp, true
	}
	return nil, false
}

func (s *Service) verifyRefreshTokenReplay(ctx context.Context, userID, role, oldJTI string) error {
	if s.rdb == nil {
		return nil
	}

	if role == RoleCivilian || role == RoleVolunteer {
		refreshKey := "refresh_token:" + userID
		storedJTI, err := s.rdb.Get(ctx, refreshKey).Result()
		if err != nil || storedJTI != oldJTI {
			// Replay attack terdeteksi di luar grace period! Revoke seluruh sesi aktif
			_ = s.rdb.Del(ctx, "session:"+userID)
			_ = s.rdb.Del(ctx, "refresh_token:"+userID)
			return errors.New("ERR_TOKEN_REUSED: Token refresh telah kedaluwarsa atau digunakan kembali")
		}
		return nil
	}

	// Console roles: per-JTI check
	jtiKey := "refresh_jti:" + oldJTI
	val, err := s.rdb.Get(ctx, jtiKey).Result()
	if err != nil || val != "valid" {
		return errors.New("ERR_TOKEN_REUSED: Token refresh telah kedaluwarsa atau digunakan kembali")
	}
	_ = s.rdb.Del(ctx, jtiKey)
	return nil
}

func (s *Service) resolveUserFullName(user *User) *string {
	var fullName *string
	switch user.Role {
	case RoleCivilian, RoleVolunteer:
		profile, _ := s.repo.FindProfile(user.ID)
		if profile != nil {
			fullName = profile.FullName
		}
	case RoleAdmin, RoleSuperAdmin:
		var ap AdminProfile
		if err := s.repo.db.Where("user_id = ?", user.ID).First(&ap).Error; err == nil {
			fullName = ap.FullName
		}
	case RoleAgencyPersonnel:
		personnel, err := s.repo.FindPersonnelByUserID(user.ID)
		if err == nil {
			fullName = &personnel.FullName
		}
	case RoleAgency:
		var agency struct {
			Name string
		}
		if err := s.repo.db.Table("agencies").Where("account_id = ?", user.ID).First(&agency).Error; err == nil {
			fullName = &agency.Name
		}
	}
	return fullName
}

func (s *Service) saveRotatedSession(ctx context.Context, user *User, resp *AuthResponse, graceKey, newAccessJTI, newRefreshJTI string) {
	if s.rdb == nil {
		return
	}

	if user.Role == RoleCivilian || user.Role == RoleVolunteer {
		_ = s.rdb.Set(ctx, "session:"+user.ID, newAccessJTI, s.cfg.JWTAccessTTL)
		_ = s.rdb.Set(ctx, "refresh_token:"+user.ID, newRefreshJTI, s.cfg.JWTRefreshTTL)
	} else {
		_ = s.rdb.Set(ctx, "refresh_jti:"+newRefreshJTI, "valid", s.cfg.JWTRefreshTTL)
	}

	respBytes, err := sonic.Marshal(resp)
	if err == nil {
		_ = s.rdb.Set(ctx, graceKey, string(respBytes), 30*time.Second)
	}
}

// RefreshToken memvalidasi refresh token, mendukung 30s grace period untuk toleransi
// sinyal fluktuatif, mendeteksi replay attack (pencurian token), dan menerbitkan token pair baru.
func (s *Service) RefreshToken(ctx context.Context, refreshTokenStr string) (*AuthResponse, error) {
	claims, err := s.parseRefreshTokenClaims(refreshTokenStr)
	if err != nil {
		return nil, err
	}

	oldJTI := claims.JTI
	userID := claims.UserID
	role := claims.Role
	graceKey := "refresh_grace:" + oldJTI

	// 1. Cek Grace-Period Window (30 detik) untuk mengantisipasi jaringan putus-nyambung
	if cachedResp, ok := s.checkGracePeriod(ctx, graceKey); ok {
		return cachedResp, nil
	}

	// 2. Cek validitas refresh token di Redis & deteksi replay attack
	if err := s.verifyRefreshTokenReplay(ctx, userID, role, oldJTI); err != nil {
		return nil, err
	}

	// 3. Ambil data user terkini dari DB
	user, err := s.repo.FindByID(userID)
	if err != nil {
		return nil, errors.New("pengguna tidak ditemukan")
	}

	// 4. Ambil full_name berdasarkan role
	fullName := s.resolveUserFullName(user)

	// 5. Generate token baru
	newAccessToken, newAccessJTI, err := utils.GenerateAccessToken(user.ID, user.Role, s.cfg.JWTSecret, s.cfg.JWTAccessTTL)
	if err != nil {
		return nil, err
	}
	newRefreshToken, newRefreshJTI, err := utils.GenerateRefreshToken(user.ID, user.Role, s.cfg.JWTSecret, s.cfg.JWTRefreshTTL)
	if err != nil {
		return nil, err
	}

	resp := &AuthResponse{
		AccessToken:  newAccessToken,
		RefreshToken: newRefreshToken,
		User: UserInfo{
			ID:       user.ID,
			Email:    user.Email,
			Role:     user.Role,
			FullName: fullName,
		},
	}

	// 6. Simpan token aktif baru di Redis dan daftarkan oldJTI ke grace cache 30 detik
	s.saveRotatedSession(ctx, user, resp, graceKey, newAccessJTI, newRefreshJTI)

	return resp, nil
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

// SubmitKYC memproses pengajuan verifikasi NIK warga.
// Warga perlu mengirimkan foto KTP dan selfie (sebagai foto profil).
func (s *Service) SubmitKYC(c *fiber.Ctx, userID, nik, fullName, placeOfBirth, dateOfBirth string) error {
	// Gunakan path absolut agar file disimpan di lokasi yang benar di VPS.
	saveDir := s.cfg.UploadDir + "/kyc"
	if err := os.MkdirAll(saveDir, 0750); err != nil {
		return fmt.Errorf("gagal membuat folder upload: %w", err)
	}

	// Upload foto KTP (wajib)
	ktpFile, err := c.FormFile("ktp")
	if err != nil {
		return errors.New("foto KTP wajib dilampirkan")
	}
	ktpExt := filepath.Ext(ktpFile.Filename)
	ktpSavePath := saveDir + "/" + userID + "_ktp" + ktpExt
	if err := c.SaveFile(ktpFile, ktpSavePath); err != nil {
		return fmt.Errorf("gagal menyimpan foto KTP: %w", err)
	}
	// URL publik yang disimpan di DB — bisa diakses dari browser/Flutter.
	ktpPublicURL := s.cfg.UploadBaseURL + "/kyc/" + userID + "_ktp" + ktpExt

	// Upload selfie (wajib) — sekaligus digunakan sebagai foto profil
	selfieFile, err := c.FormFile("selfie")
	if err != nil {
		return errors.New("foto selfie wajib dilampirkan untuk verifikasi identitas")
	}
	selfieExt := filepath.Ext(selfieFile.Filename)
	selfieSavePath := saveDir + "/" + userID + "_selfie" + selfieExt
	if err := c.SaveFile(selfieFile, selfieSavePath); err != nil {
		return fmt.Errorf("gagal menyimpan foto selfie: %w", err)
	}
	selfiePublicURL := s.cfg.UploadBaseURL + "/kyc/" + userID + "_selfie" + selfieExt

	err = s.repo.SubmitKYC(userID, nik, fullName, placeOfBirth, dateOfBirth, ktpPublicURL, selfiePublicURL)
	if err != nil {
		if err.Error() == "NIK_ALREADY_USED" {
			return errors.New("NIK ini sudah terdaftar pada akun lain. Pastikan NIK yang Anda masukkan benar")
		}
		return err
	}
	return nil
}

// GetKYCStatus mengembalikan status verifikasi NIK warga.
func (s *Service) GetKYCStatus(userID string) (*KYCStatusResponse, error) {
	profile, err := s.repo.GetKYCStatus(userID)
	if err != nil {
		return nil, err
	}
	msg := map[string]string{
		string(KYCStatusNone):     "Anda belum mengajukan verifikasi NIK.",
		string(KYCStatusPending):  "Pengajuan sedang diproses oleh admin (1-3 hari kerja).",
		string(KYCStatusApproved): "Identitas Anda telah terverifikasi",
		string(KYCStatusRejected): "Pengajuan ditolak. Silakan ajukan ulang dengan foto yang lebih jelas.",
	}[profile.NIKVerificationStatus]
	return &KYCStatusResponse{
		Status:          KYCStatus(profile.NIKVerificationStatus),
		NIK:             profile.NIK,
		ProfilePhotoURL: profile.ProfilePhotoURL,
		Message:         msg,
	}, nil
}
