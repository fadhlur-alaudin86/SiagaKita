package user

import (
	"strings"

	"siagakita-backend/internal/utils"

	"github.com/gofiber/fiber/v2"
)

// Handler holds HTTP handlers for the user domain.
type Handler struct {
	svc *Service
}

// NewHandler creates a new user Handler.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// ─── POST /api/v1/auth/register ───────────────────────────────────────────────
func (h *Handler) Register(c *fiber.Ctx) error {
	var req RegisterRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}
	result, err := h.svc.Register(c.Context(), &req)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.CreatedResponse(c, result)
}

// ─── POST /api/v1/auth/verify-register-otp ───────────────────────────────────
func (h *Handler) VerifyRegisterOTP(c *fiber.Ctx) error {
	var req VerifyEmailOTPRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}
	if req.Email == "" || req.OTPCode == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "email dan otp_code wajib diisi")
	}
	resp, err := h.svc.VerifyRegisterOTP(c.Context(), req.Email, req.OTPCode)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.SuccessResponse(c, resp)
}

// ─── POST /api/v1/auth/login (civilian & volunteer via mobile) ────────────────
func (h *Handler) Login(c *fiber.Ctx) error {
	var req LoginRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}
	resp, err := h.svc.Login(c.Context(), &req)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, err.Error())
	}
	return utils.SuccessResponse(c, resp)
}

// ─── POST /api/v1/auth/console/login (admin, superadmin, agency via desktop) ──
func (h *Handler) ConsoleLogin(c *fiber.Ctx) error {
	var req LoginRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}
	resp, err := h.svc.ConsoleLogin(c.Context(), &req)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, err.Error())
	}
	return utils.SuccessResponse(c, resp)
}

// ─── POST /api/v1/auth/personnel/login (agency_personnel via mobile responder) ─
func (h *Handler) PersonnelLogin(c *fiber.Ctx) error {
	var req LoginRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}
	resp, err := h.svc.PersonnelLogin(c.Context(), &req)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, err.Error())
	}
	return utils.SuccessResponse(c, resp)
}

// ─── POST /api/v1/auth/verify-login-otp ──────────────────────────────────────
func (h *Handler) VerifyLoginOTP(c *fiber.Ctx) error {
	var req VerifyEmailOTPRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}
	if req.Email == "" || req.OTPCode == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "email dan otp_code wajib diisi")
	}
	resp, err := h.svc.VerifyLoginOTP(c.Context(), req.Email, req.OTPCode)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.SuccessResponse(c, resp)
}

// ─── POST /api/v1/auth/refresh-token (public) ────────────────────────────────
func (h *Handler) RefreshToken(c *fiber.Ctx) error {
	var req RefreshTokenRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}
	if req.RefreshToken == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "refresh_token wajib diisi")
	}

	resp, err := h.svc.RefreshToken(c.Context(), req.RefreshToken)
	if err != nil {
		if strings.HasPrefix(err.Error(), "ERR_TOKEN_REUSED") {
			return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Token refresh telah kedaluwarsa atau digunakan kembali")
		}
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, err.Error())
	}
	return utils.SuccessResponse(c, resp)
}

// ─── POST /api/v1/users/biodata  [Auth required — civilian/volunteer] ─────────
func (h *Handler) SaveBiodata(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	var req BiodataRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}
	if err := h.svc.SaveBiodata(userID, &req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, fiber.Map{fieldMessage: "Biodata berhasil disimpan"})
}

// ─── GET /api/v1/users/profile  [Auth required — civilian/volunteer] ──────────
func (h *Handler) GetProfile(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	profile, err := h.svc.GetProfile(userID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusNotFound, "Profil tidak ditemukan")
	}
	return utils.SuccessResponse(c, profile)
}

// ─── PUT /api/v1/users/profile  [Auth required — civilian/volunteer] ──────────
func (h *Handler) UpdateProfile(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	var req UpdateProfileRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}
	if err := h.svc.UpdateProfile(userID, &req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	profile, err := h.svc.GetProfile(userID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Gagal memuat profil terbaru")
	}
	return utils.SuccessResponse(c, profile)
}

// ─── POST /api/v1/users/phone/request-otp  [Auth required] ───────────────────
func (h *Handler) RequestPhoneVerification(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	var req PhoneUpdateRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}
	if req.PhoneNumber == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "phone_number wajib diisi")
	}
	if err := h.svc.RequestPhoneVerification(c.Context(), userID, req.PhoneNumber); err != nil {
		if err.Error() == "Tunggu 1 menit sebelum meminta kode baru" {
			return utils.ErrorResponse(c, fiber.StatusTooManyRequests, err.Error())
		}
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, fiber.Map{
		fieldMessage: "Kode OTP telah dikirimkan ke WhatsApp Anda. Berlaku 3 menit.",
	})
}

// ─── POST /api/v1/users/phone/verify-otp  [Auth required] ────────────────────
func (h *Handler) ConfirmPhoneOTP(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	var req VerifyPhoneRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}
	if req.PhoneNumber == "" || req.OTPCode == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "phone_number dan otp_code wajib diisi")
	}
	if err := h.svc.ConfirmPhoneOTP(c.Context(), userID, req.PhoneNumber, req.OTPCode); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.SuccessResponse(c, fiber.Map{
		fieldMessage: "Nomor HP berhasil diverifikasi.",
		"verified":   true,
	})
}

// ─── Password Reset & Resend OTP ──────────────────────────────────────────────

func (h *Handler) ForgotPassword(c *fiber.Ctx) error {
	var req ForgotPasswordRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Format JSON tidak valid")
	}
	if req.Email == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Email wajib diisi")
	}
	if err := h.svc.ForgotPassword(c.Context(), req.Email); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.SuccessResponse(c, "Kode OTP untuk reset password telah dikirim ke email")
}

func (h *Handler) ResetPassword(c *fiber.Ctx) error {
	var req ResetPasswordRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Format JSON tidak valid")
	}
	if req.Email == "" || req.OTP == "" || req.NewPassword == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Email, OTP, dan Password baru wajib diisi")
	}
	if err := h.svc.ResetPassword(c.Context(), req.Email, req.OTP, req.NewPassword); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.SuccessResponse(c, "Password berhasil diubah, silakan login kembali")
}

func (h *Handler) ResendOTP(c *fiber.Ctx) error {
	var req ResendOTPRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Format JSON tidak valid")
	}
	if req.Email == "" || req.Context == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Email dan context wajib diisi")
	}
	if err := h.svc.ResendOTP(c.Context(), req.Email, req.Context); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.SuccessResponse(c, "Kode OTP telah dikirim ulang ke email")
}

// ─── KYC Warga ───────────────────────────────────────────────────────────────

// POST /api/v1/users/kyc  [Auth required — civilian/volunteer]
// Menerima multipart/form-data: nik, full_name, ktp (file), selfie (file)
func (h *Handler) SubmitKYC(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)

	nik := c.FormValue("nik")
	fullName := c.FormValue("full_name")
	placeOfBirth := c.FormValue("place_of_birth")
	dateOfBirth := c.FormValue("date_of_birth")
	if nik == "" || fullName == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "nik dan full_name wajib diisi")
	}
	if len(nik) != 16 {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "NIK harus 16 digit")
	}
	if len(fullName) > 100 {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Nama lengkap maksimal 100 karakter")
	}
	if len(placeOfBirth) > 100 {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Tempat lahir maksimal 100 karakter")
	}

	if err := h.svc.SubmitKYC(c, userID, nik, fullName, placeOfBirth, dateOfBirth); err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, fiber.Map{
		fieldMessage: "Pengajuan verifikasi NIK berhasil dikirim. Tunggu proses verifikasi admin (1-3 hari kerja).",
		"status":     string(KYCStatusPending),
	})
}

// GET /api/v1/users/kyc/status  [Auth required — civilian/volunteer]
func (h *Handler) GetKYCStatus(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	resp, err := h.svc.GetKYCStatus(userID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusNotFound, "Data profil tidak ditemukan")
	}
	return utils.SuccessResponse(c, resp)
}

// ─── Pendaftaran Relawan ──────────────────────────────────────────────────────

// POST /api/v1/users/volunteer/register  [Auth required — civilian]
func (h *Handler) SubmitVolunteerRegistration(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)

	var req RegisterVolunteerRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}

	if err := h.svc.SubmitVolunteerRegistration(c, userID, req.Experience, req.Specializations); err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}

	return utils.SuccessResponse(c, fiber.Map{
		fieldMessage: "Pengajuan pendaftaran relawan berhasil dikirim. Tunggu proses verifikasi admin.",
		"status":     string(KYCStatusPending),
	})
}

// ─── FCM Token Management ───────────────────────────────────────────────────

// PUT /api/v1/users/profile/fcm-token
// POST /api/v1/notifications/register-token
func (h *Handler) UpdateFCMToken(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Unauthorized")
	}

	var req UpdateFCMTokenRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}
	if strings.TrimSpace(req.FCMToken) == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "fcm_token wajib diisi")
	}

	if err := h.svc.UpdateFCMToken(userID, req.FCMToken); err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Gagal memperbarui FCM token")
	}

	return utils.SuccessResponseWithMsg(c, "FCM token berhasil diperbarui", nil)
}

// DELETE /api/v1/users/profile/fcm-token
func (h *Handler) ClearFCMToken(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Unauthorized")
	}

	if err := h.svc.ClearFCMToken(userID); err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Gagal menghapus FCM token")
	}

	return utils.SuccessResponseWithMsg(c, "FCM token berhasil dihapus", nil)
}
