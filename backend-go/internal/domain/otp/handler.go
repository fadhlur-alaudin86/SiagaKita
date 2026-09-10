package otp

import (
	"github.com/gofiber/fiber/v2"
)

// Handler memegang referensi ke OTP service dan mengekspos HTTP handler.
type Handler struct {
	svc Service
}

// NewHandler membuat instance OTP handler.
func NewHandler(svc Service) *Handler {
	return &Handler{svc: svc}
}

const (
	fieldSuccess = "success"
	fieldMessage = "message"
)

// ─── Request / Response types ─────────────────────────────────────────────────

type requestOTPRequest struct {
	PhoneNumber string `json:"phone_number"`
}

type verifyOTPRequest struct {
	PhoneNumber string `json:"phone_number"`
	OTPCode     string `json:"otp_code"`
}

// ─── POST /api/v1/auth/request-otp ───────────────────────────────────────────

// RequestOTP godoc
// @Summary Minta kode OTP via WhatsApp
// @Tags auth
// @Accept json
// @Produce json
// @Param body body requestOTPRequest true "Nomor HP"
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} map[string]interface{}
// @Failure 429 {object} map[string]interface{}
// @Router /auth/request-otp [post]
func (h *Handler) RequestOTP(c *fiber.Ctx) error {
	var req requestOTPRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			fieldSuccess: false,
			fieldMessage: "Format request tidak valid",
		})
	}

	if req.PhoneNumber == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			fieldSuccess: false,
			fieldMessage: "phone_number tidak boleh kosong",
		})
	}

	if err := h.svc.RequestOTP(c.Context(), req.PhoneNumber); err != nil {
		// Bedakan rate-limit (429) vs error server (500)
		if err.Error() == "Tunggu 1 menit sebelum meminta kode baru" {
			return c.Status(fiber.StatusTooManyRequests).JSON(fiber.Map{
				fieldSuccess: false,
				fieldMessage: err.Error(),
			})
		}
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			fieldSuccess: false,
			fieldMessage: err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		fieldSuccess: true,
		"data": fiber.Map{
			fieldMessage: "Kode OTP telah dikirimkan ke WhatsApp Anda. Berlaku 3 menit.",
		},
	})
}

// ─── POST /api/v1/auth/verify-otp ────────────────────────────────────────────

// VerifyOTP godoc
// @Summary Verifikasi kode OTP
// @Tags auth
// @Accept json
// @Produce json
// @Param body body verifyOTPRequest true "Nomor HP + kode OTP"
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} map[string]interface{}
// @Router /auth/verify-otp [post]
func (h *Handler) VerifyOTP(c *fiber.Ctx) error {
	var req verifyOTPRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			fieldSuccess: false,
			fieldMessage: "Format request tidak valid",
		})
	}

	if req.PhoneNumber == "" || req.OTPCode == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			fieldSuccess: false,
			fieldMessage: "phone_number dan otp_code wajib diisi",
		})
	}

	if err := h.svc.VerifyOTP(c.Context(), req.PhoneNumber, req.OTPCode); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			fieldSuccess: false,
			fieldMessage: err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		fieldSuccess: true,
		"data": fiber.Map{
			"verified": true,
		},
	})
}
