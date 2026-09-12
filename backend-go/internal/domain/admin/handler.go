package admin

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"siagakita-backend/internal/config"
	"siagakita-backend/internal/utils"

	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
)

// Handler holds HTTP handlers for the admin domain.
type Handler struct {
	svc *Service
	cfg *config.Config
}

func NewHandler(svc *Service, cfg *config.Config) *Handler {
	return &Handler{svc: svc, cfg: cfg}
}

// ─── KYC Relawan ──────────────────────────────────────────────────────────────

// GET /api/v1/admin/volunteers/pending  [AdminOnly]
func (h *Handler) GetPendingKYC(c *fiber.Ctx) error {
	list, err := h.svc.GetPendingKYC()
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}

	pageStr := c.Query("page")
	limitStr := c.Query("limit")
	if pageStr != "" || limitStr != "" {
		page, _ := strconv.Atoi(pageStr)
		if page < 1 {
			page = 1
		}
		limit, _ := strconv.Atoi(limitStr)
		if limit < 1 {
			limit = 20
		}
		total := len(list)
		c.Set("X-Total-Count", strconv.Itoa(total))
		c.Set("X-Page", strconv.Itoa(page))
		c.Set("X-Limit", strconv.Itoa(limit))

		start := (page - 1) * limit
		if start >= total {
			return utils.SuccessResponse(c, []VolunteerKYC{})
		}
		end := start + limit
		if end > total {
			end = total
		}
		return utils.SuccessResponse(c, list[start:end])
	}

	return utils.SuccessResponse(c, list)
}

// POST /api/v1/admin/volunteers/:id/approve  [AdminOnly]
func (h *Handler) ApproveKYC(c *fiber.Ctx) error {
	targetUserID := c.Params("id")
	callerID, _ := c.Locals("userID").(string)

	if err := h.svc.ApproveKYC(targetUserID, callerID); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return utils.ErrorResponse(c, fiber.StatusNotFound, "Data relawan atau pengajuan sertifikat pending tidak ditemukan")
		}
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, fiber.Map{
		fieldMessage: "Relawan berhasil diverifikasi.",
	})
}

// POST /api/v1/admin/volunteers/:id/reject  [AdminOnly]
func (h *Handler) RejectKYC(c *fiber.Ctx) error {
	targetUserID := c.Params("id")
	callerID, _ := c.Locals("userID").(string)

	var req RejectKYCRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}
	if err := h.svc.RejectKYC(targetUserID, callerID, req.Reason); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return utils.ErrorResponse(c, fiber.StatusNotFound, "Data relawan atau pengajuan sertifikat pending tidak ditemukan")
		}
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, fiber.Map{
		fieldMessage: "KYC relawan ditolak.",
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
		fieldMessage: "Akun admin berhasil dibuat.",
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
		fieldMessage: "Akun instansi berhasil dibuat.",
	})
}

// GET /api/v1/admin/users?role=volunteer&banned=true&high_strike=true&search=...  [AdminOnly]
func (h *Handler) GetUsers(c *fiber.Ctx) error {
	filterBanned := c.Query("banned") == "true"
	filterHighStrike := c.Query("high_strike") == "true"
	search := c.Query("search", "")
	role := c.Query("role", "")

	users, err := h.svc.GetUsers(filterBanned, filterHighStrike, search, role)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, users)
}

// POST /api/v1/admin/users/:id/ban  [AdminOnly]
func (h *Handler) BanUser(c *fiber.Ctx) error {
	targetUserID := c.Params("id")
	callerID, _ := c.Locals("userID").(string)

	var req BanUserRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}
	if err := h.svc.BanUser(targetUserID, &req, callerID); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return utils.ErrorResponse(c, fiber.StatusNotFound, "Pengguna tidak ditemukan")
		}
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, fiber.Map{fieldMessage: "User berhasil di-ban dari fitur SOS."})
}

// POST /api/v1/admin/users/:id/unban  [AdminOnly]
func (h *Handler) UnbanUser(c *fiber.Ctx) error {
	targetUserID := c.Params("id")
	callerID, _ := c.Locals("userID").(string)

	if err := h.svc.UnbanUser(targetUserID, callerID); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return utils.ErrorResponse(c, fiber.StatusNotFound, "Pengguna tidak ditemukan")
		}
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, fiber.Map{fieldMessage: "Ban pengguna berhasil dicabut."})
}

// DELETE /api/v1/admin/users/:id/strike  [AdminOnly]
func (h *Handler) ResetStrike(c *fiber.Ctx) error {
	targetUserID := c.Params("id")
	callerID, _ := c.Locals("userID").(string)

	if err := h.svc.ResetStrike(targetUserID, callerID); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return utils.ErrorResponse(c, fiber.StatusNotFound, "Pengguna tidak ditemukan")
		}
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, fiber.Map{fieldMessage: "Strike pengguna berhasil direset."})
}

// GET /api/v1/admin/users/:id/detail  [AdminOnly]
func (h *Handler) GetUserDetail(c *fiber.Ctx) error {
	targetUserID := c.Params("id")
	detail, err := h.svc.GetUserDetail(targetUserID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusNotFound, err.Error())
	}
	return utils.SuccessResponse(c, detail)
}

// ─── KYC Warga (NIK Verification) ────────────────────────────────────────────

// GET /api/v1/admin/users/kyc/warga  [AdminOnly]
func (h *Handler) GetPendingWargaKYC(c *fiber.Ctx) error {
	list, err := h.svc.GetPendingWargaKYC()
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, list)
}

// POST /api/v1/admin/users/kyc/warga/:id/approve  [AdminOnly]
func (h *Handler) ApproveWargaKYC(c *fiber.Ctx) error {
	targetUserID := c.Params("id")
	if err := h.svc.ApproveWargaKYC(targetUserID); err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, fiber.Map{fieldMessage: "Verifikasi NIK warga disetujui."})
}

// POST /api/v1/admin/users/kyc/warga/:id/reject  [AdminOnly]
func (h *Handler) RejectWargaKYC(c *fiber.Ctx) error {
	targetUserID := c.Params("id")
	if err := h.svc.RejectWargaKYC(targetUserID); err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, fiber.Map{fieldMessage: "Verifikasi NIK warga ditolak."})
}

// ─── Agency & Admin Listings ──────────────────────────────────────────────────

// GET /api/v1/admin/agencies  [AdminOnly]
func (h *Handler) GetAgencies(c *fiber.Ctx) error {
	list, err := h.svc.GetAgencies()
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, list)
}

// GET /api/v1/admin/admins  [SuperAdminOnly]
func (h *Handler) GetAdmins(c *fiber.Ctx) error {
	list, err := h.svc.GetAdmins()
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, list)
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
		if errors.Is(err, ErrRankNotFound) {
			return utils.ErrorResponse(c, fiber.StatusNotFound, err.Error())
		}
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
		if errors.Is(err, ErrRankNotFound) {
			return utils.ErrorResponse(c, fiber.StatusNotFound, err.Error())
		}
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.SuccessResponse(c, fiber.Map{fieldMessage: "Rank berhasil dihapus."})
}

// ─── Statistics ───────────────────────────────────────────────────────────────

// GET /api/v1/admin/stats?period=month  [ConsoleOnly]
func (h *Handler) GetStats(c *fiber.Ctx) error {
	period := c.Query("period", "month") // week | month | year (also accepts weekly | monthly | yearly)
	stats, err := h.svc.GetStats(period)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, stats)
}

// ─── Badges (Peringkat Relawan) ────────────────────────────────────────────────

// GET /api/v1/admin/badges  [ConsoleOnly]
func (h *Handler) GetBadges(c *fiber.Ctx) error {
	badges, err := h.svc.GetBadges()
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, badges)
}

// POST /api/v1/admin/badges  [AdminOnly]
func (h *Handler) CreateBadge(c *fiber.Ctx) error {
	form, err := c.MultipartForm()
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Form tidak valid")
	}

	req := BadgeRequest{}
	if codes := form.Value["badge_code"]; len(codes) > 0 {
		req.BadgeCode = codes[0]
	}
	if names := form.Value["badge_name"]; len(names) > 0 {
		req.BadgeName = names[0]
	}
	if levels := form.Value["level"]; len(levels) > 0 {
		if lvl, err := strconv.Atoi(levels[0]); err == nil {
			req.Level = lvl
		}
	}
	if thresholds := form.Value["threshold"]; len(thresholds) > 0 {
		if th, err := strconv.Atoi(thresholds[0]); err == nil {
			req.Threshold = th
		}
	}
	if descs := form.Value["description"]; len(descs) > 0 {
		req.Description = descs[0]
	}

	if icons := form.File["icon"]; len(icons) > 0 {
		fh := icons[0]
		if fh.Size <= 5<<20 {
			ext := filepath.Ext(fh.Filename)
			now := time.Now()
			dir := filepath.Join(h.cfg.UploadDir, "gamification", "badges")
			_ = os.MkdirAll(dir, 0750)
			fileName := fmt.Sprintf("badge_%d%s", now.UnixNano(), ext)
			dst := filepath.Join(dir, fileName)
			if err := c.SaveFile(fh, dst); err == nil {
				req.IconURL = fmt.Sprintf("%s/gamification/badges/%s", h.cfg.UploadBaseURL, fileName)
			}
		}
	}

	if req.BadgeName == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Nama badge wajib diisi")
	}

	badge, err := h.svc.CreateBadge(&req)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.CreatedResponse(c, badge)
}

// PUT /api/v1/admin/badges/:id  [AdminOnly]
func (h *Handler) UpdateBadge(c *fiber.Ctx) error {
	id := c.Params("id")
	form, err := c.MultipartForm()
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Form tidak valid")
	}

	req := BadgeRequest{}
	if codes := form.Value["badge_code"]; len(codes) > 0 {
		req.BadgeCode = codes[0]
	}
	if names := form.Value["badge_name"]; len(names) > 0 {
		req.BadgeName = names[0]
	}
	if levels := form.Value["level"]; len(levels) > 0 {
		if lvl, err := strconv.Atoi(levels[0]); err == nil {
			req.Level = lvl
		}
	}
	if thresholds := form.Value["threshold"]; len(thresholds) > 0 {
		if th, err := strconv.Atoi(thresholds[0]); err == nil {
			req.Threshold = th
		}
	}
	if descs := form.Value["description"]; len(descs) > 0 {
		req.Description = descs[0]
	}
	if iconUrls := form.Value["icon_url"]; len(iconUrls) > 0 {
		req.IconURL = iconUrls[0] // fallback if no file is uploaded
	}

	if icons := form.File["icon"]; len(icons) > 0 {
		fh := icons[0]
		if fh.Size <= 5<<20 {
			ext := filepath.Ext(fh.Filename)
			now := time.Now()
			dir := filepath.Join(h.cfg.UploadDir, "gamification", "badges")
			_ = os.MkdirAll(dir, 0750)
			fileName := fmt.Sprintf("badge_%d%s", now.UnixNano(), ext)
			dst := filepath.Join(dir, fileName)
			if err := c.SaveFile(fh, dst); err == nil {
				req.IconURL = fmt.Sprintf("%s/gamification/badges/%s", h.cfg.UploadBaseURL, fileName)
			}
		}
	}

	badge, err := h.svc.UpdateBadge(id, &req)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.SuccessResponse(c, badge)
}

// DELETE /api/v1/admin/badges/:id  [AdminOnly]
func (h *Handler) DeleteBadge(c *fiber.Ctx) error {
	id := c.Params("id")
	if err := h.svc.DeleteBadge(id); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.SuccessResponse(c, fiber.Map{fieldMessage: "Badge berhasil dihapus."})
}
