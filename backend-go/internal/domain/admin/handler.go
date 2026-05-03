package admin

import (
	"strconv"

	"siagakita-backend/internal/utils"

	"github.com/gofiber/fiber/v2"
)

// Handler holds HTTP handlers for the admin domain.
type Handler struct {
	svc *Service
}

func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// ─── KYC Relawan ──────────────────────────────────────────────────────────────

// GET /api/v1/admin/volunteers/pending  [AdminOnly]
func (h *Handler) GetPendingKYC(c *fiber.Ctx) error {
	list, err := h.svc.GetPendingKYC()
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, list)
}

// POST /api/v1/admin/volunteers/:id/approve  [AdminOnly]
func (h *Handler) ApproveKYC(c *fiber.Ctx) error {
	targetUserID := c.Params("id")
	callerID := c.Locals("userID").(string)

	if err := h.svc.ApproveKYC(targetUserID, callerID); err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, fiber.Map{
		"message": "Relawan berhasil diverifikasi.",
	})
}

// POST /api/v1/admin/volunteers/:id/reject  [AdminOnly]
func (h *Handler) RejectKYC(c *fiber.Ctx) error {
	targetUserID := c.Params("id")
	callerID := c.Locals("userID").(string)

	var req RejectKYCRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}
	if err := h.svc.RejectKYC(targetUserID, callerID, req.Reason); err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, fiber.Map{
		"message": "KYC relawan ditolak.",
	})
}

// ─── User Management ──────────────────────────────────────────────────────────

// POST /api/v1/admin/admins  [SuperAdminOnly]
func (h *Handler) CreateAdmin(c *fiber.Ctx) error {
	callerID := c.Locals("userID").(string)

	var req CreateAdminRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}

	if err := h.svc.CreateAdmin(&req, callerID); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error())
	}

	return utils.SuccessResponse(c, fiber.Map{
		"message": "Akun admin berhasil dibuat.",
	})
}

// POST /api/v1/admin/agencies  [AdminOnly]
func (h *Handler) CreateAgency(c *fiber.Ctx) error {
	var req CreateAgencyRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}

	if err := h.svc.CreateAgency(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error())
	}

	return utils.SuccessResponse(c, fiber.Map{
		"message": "Akun instansi (agency) berhasil dibuat.",
	})
}

// GET /api/v1/admin/users?banned=true&high_strike=true&search=...  [AdminOnly]
func (h *Handler) GetUsers(c *fiber.Ctx) error {
	filterBanned := c.Query("banned") == "true"
	filterHighStrike := c.Query("high_strike") == "true"
	search := c.Query("search", "")

	users, err := h.svc.GetUsers(filterBanned, filterHighStrike, search)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, users)
}

// POST /api/v1/admin/users/:id/ban  [AdminOnly]
func (h *Handler) BanUser(c *fiber.Ctx) error {
	targetUserID := c.Params("id")

	var req BanUserRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}
	if err := h.svc.BanUser(targetUserID, req.Reason); err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, fiber.Map{"message": "User berhasil di-ban dari fitur SOS."})
}

// POST /api/v1/admin/users/:id/unban  [AdminOnly]
func (h *Handler) UnbanUser(c *fiber.Ctx) error {
	targetUserID := c.Params("id")
	if err := h.svc.UnbanUser(targetUserID); err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, fiber.Map{"message": "Ban pengguna berhasil dicabut."})
}

// DELETE /api/v1/admin/users/:id/strike  [AdminOnly]
func (h *Handler) ResetStrike(c *fiber.Ctx) error {
	targetUserID := c.Params("id")
	if err := h.svc.ResetStrike(targetUserID); err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, fiber.Map{"message": "Strike pengguna berhasil direset."})
}

// ─── Master Data: Ranks ───────────────────────────────────────────────────────

// GET /api/v1/admin/ranks  [ConsoleOnly]
func (h *Handler) GetRanks(c *fiber.Ctx) error {
	ranks, err := h.svc.GetRanks()
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, ranks)
}

// POST /api/v1/admin/ranks  [AdminOnly]
func (h *Handler) CreateRank(c *fiber.Ctx) error {
	var req RankRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}
	rank, err := h.svc.CreateRank(&req)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.CreatedResponse(c, rank)
}

// PUT /api/v1/admin/ranks/:id  [AdminOnly]
func (h *Handler) UpdateRank(c *fiber.Ctx) error {
	id, err := strconv.Atoi(c.Params("id"))
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "ID rank tidak valid")
	}
	var req RankRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}
	rank, err := h.svc.UpdateRank(id, &req)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.SuccessResponse(c, rank)
}

// DELETE /api/v1/admin/ranks/:id  [AdminOnly]
func (h *Handler) DeleteRank(c *fiber.Ctx) error {
	id, err := strconv.Atoi(c.Params("id"))
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "ID rank tidak valid")
	}
	if err := h.svc.DeleteRank(id); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.SuccessResponse(c, fiber.Map{"message": "Rank berhasil dihapus."})
}

// ─── Statistics ───────────────────────────────────────────────────────────────

// GET /api/v1/admin/stats  [ConsoleOnly]
func (h *Handler) GetStats(c *fiber.Ctx) error {
	stats, err := h.svc.GetStats()
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, stats)
}
