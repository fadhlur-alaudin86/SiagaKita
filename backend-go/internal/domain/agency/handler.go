package agency

import (
	"siagakita-backend/internal/utils"

	"github.com/gofiber/fiber/v2"
)

type Handler struct {
	svc *Service
}

func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// POST /api/v1/agencies/personnels  [AgencyOnly]
func (h *Handler) CreatePersonnel(c *fiber.Ctx) error {
	callerID := c.Locals("userID").(string)

	var req CreatePersonnelRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}

	if err := h.svc.CreatePersonnel(&req, callerID); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error())
	}

	return utils.SuccessResponse(c, fiber.Map{
		"message": "Akun personil lapangan berhasil didaftarkan.",
	})
}

// GET /api/v1/agencies/me  [AgencyOnly]
func (h *Handler) GetMyProfile(c *fiber.Ctx) error {
	callerID := c.Locals("userID").(string)

	profile, err := h.svc.GetMyProfile(callerID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusNotFound, err.Error())
	}

	return utils.SuccessResponse(c, profile)
}
