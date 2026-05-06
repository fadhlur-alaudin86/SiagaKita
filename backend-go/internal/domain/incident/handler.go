package incident

import (
	"context"
	"fmt"
	"io"
	"log"
	"mime/multipart"
	"os"
	"path/filepath"
	"time"

	"siagakita-backend/internal/config"
	"siagakita-backend/internal/hub"
	"siagakita-backend/internal/utils"

	"github.com/gofiber/fiber/v2"
	"github.com/redis/go-redis/v9"
)

type Handler struct {
	svc *Service
	cfg *config.Config
	hub *hub.Hub
	rdb *redis.Client
}

func NewHandler(svc *Service, cfg *config.Config, h *hub.Hub, rdb *redis.Client) *Handler {
	return &Handler{svc: svc, cfg: cfg, hub: h, rdb: rdb}
}

// POST /api/v1/incidents/trigger
func (h *Handler) TriggerSOS(c *fiber.Ctx) error {
	reporterID := c.Locals("userID").(string)

	var req TriggerSOSRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}
	if req.Latitude == 0 && req.Longitude == 0 {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Koordinat GPS wajib diisi")
	}

	trustLabel := determineTrustLabel(c)

	resp, err := h.svc.TriggerSOS(reporterID, &req, trustLabel)
	if err != nil {
		if isBanError(err) {
			return utils.ErrorResponse(c, fiber.StatusForbidden, err.Error())
		}
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}

	return utils.CreatedResponse(c, resp)
}

// PATCH /api/v1/incidents/:id/type — pilih tipe di grace period
func (h *Handler) UpdateType(c *fiber.Ctx) error {
	reporterID := c.Locals("userID").(string)
	incidentID := c.Params("id")

	var req UpdateTypeRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}

	if err := h.svc.UpdateType(incidentID, reporterID, req.IncidentType); err != nil {
		status := fiber.StatusInternalServerError
		if err.Error() == "unauthorized" {
			status = fiber.StatusForbidden
		}
		return utils.ErrorResponse(c, status, err.Error())
	}

	// Broadcast via WS setelah tipe diubah dan status menjadi broadcasting
	go h.broadcastSOSViaREST(incidentID)

	return utils.SuccessResponse(c, fiber.Map{"updated": true, "message": "Tipe insiden diperbarui, SOS sedang disiarkan."})
}

// POST /api/v1/incidents/:id/broadcast — grace period timeout, tipe tetap 'unknown'
func (h *Handler) Broadcast(c *fiber.Ctx) error {
	reporterID := c.Locals("userID").(string)
	incidentID := c.Params("id")

	if err := h.svc.PromoteToBroadcasting(incidentID, reporterID); err != nil {
		status := fiber.StatusInternalServerError
		if err.Error() == "unauthorized" {
			status = fiber.StatusForbidden
		}
		return utils.ErrorResponse(c, status, err.Error())
	}

	// Broadcast via WS setelah grace period berakhir (dipanggil dari REST)
	go h.broadcastSOSViaREST(incidentID)

	return utils.SuccessResponse(c, fiber.Map{"broadcasting": true, "message": "SOS sedang disiarkan ke relawan dan instansi terdekat."})
}

// POST /api/v1/incidents/:id/cancel
func (h *Handler) CancelSOS(c *fiber.Ctx) error {
	reporterID := c.Locals("userID").(string)
	incidentID := c.Params("id")

	if err := h.svc.CancelSOS(incidentID, reporterID); err != nil {
		status := fiber.StatusInternalServerError
		if err.Error() == "unauthorized" {
			status = fiber.StatusForbidden
		}
		return utils.ErrorResponse(c, status, err.Error())
	}

	return utils.SuccessResponse(c, fiber.Map{"cancelled": true})
}

// PUT /api/v1/incidents/:id/location
func (h *Handler) UpdateLocation(c *fiber.Ctx) error {
	incidentID := c.Params("id")

	var req UpdateLocationRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}

	if err := h.svc.UpdateLocation(incidentID, req.Latitude, req.Longitude); err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}

	return utils.SuccessResponse(c, fiber.Map{"updated": true})
}

// GET /api/v1/incidents/active
func (h *Handler) GetActive(c *fiber.Ctx) error {
	reporterID := c.Locals("userID").(string)

	resp, err := h.svc.GetActive(reporterID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}

	return utils.SuccessResponse(c, resp)
}

// GET /api/v1/incidents/my-history
func (h *Handler) GetHistory(c *fiber.Ctx) error {
	reporterID := c.Locals("userID").(string)

	resp, err := h.svc.GetHistory(reporterID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}

	return utils.SuccessResponse(c, resp)
}

// GET /api/v1/incidents/all-active — untuk console desktop (agency/admin)
func (h *Handler) GetAllActive(c *fiber.Ctx) error {
	incidents, err := h.svc.GetAllActive()
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, incidents)
}

// POST /api/v1/incidents/:id/mark-false-alarm
func (h *Handler) MarkFalseAlarm(c *fiber.Ctx) error {
	adminID := c.Locals("userID").(string)
	incidentID := c.Params("id")

	var req MarkFalseAlarmRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}
	if req.Reason == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Alasan (reason) wajib diisi")
	}

	resp, err := h.svc.MarkFalseAlarm(incidentID, adminID, req.Reason)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}

	return utils.SuccessResponse(c, resp)
}

// POST /api/v1/incidents/:id/resolve
func (h *Handler) Resolve(c *fiber.Ctx) error {
	responderID := c.Locals("userID").(string)
	incidentID := c.Params("id")

	resp, err := h.svc.Resolve(incidentID, responderID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}

	return utils.SuccessResponse(c, resp)
}

// POST /api/v1/reports — Jalur B laporan warga (multipart/form-data)
func (h *Handler) CreateReport(c *fiber.Ctx) error {
	reporterID := c.Locals("userID").(string)

	// Parse form fields (works for both multipart and url-encoded)
	req := CreateReportRequest{
		IncidentType: c.FormValue("incident_type"),
		Description:  c.FormValue("description"),
		Latitude:     parseFloat(c.FormValue("latitude")),
		Longitude:    parseFloat(c.FormValue("longitude")),
		UrgencyLevel: parseInt(c.FormValue("urgency_level"), 1),
	}

	if req.IncidentType == "" || req.IncidentType == "unknown" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "incident_type wajib diisi")
	}
	if req.Latitude == 0 && req.Longitude == 0 {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Koordinat GPS wajib diisi")
	}

	uploadDir := h.cfg.UploadDir
	baseURL := h.cfg.UploadBaseURL
	now := time.Now()
	yearMonth := fmt.Sprintf("%d/%02d", now.Year(), now.Month())

	var photoPaths []string
	var audioPath *string

	// Process photos (max 3, max 2 MB each)
	if form, err := c.MultipartForm(); err == nil {
		photos := form.File["photos[]"]
		if len(photos) > 3 {
			photos = photos[:3]
		}
		for i, fh := range photos {
			if fh.Size > 2<<20 {
				continue
			}
			ext := filepath.Ext(fh.Filename)
			if ext == "" {
				ext = ".jpg"
			}
			// Use reporterID as temp dir key before report is created
			dir := filepath.Join(uploadDir, "reports", "photos", yearMonth, reporterID)
			_ = os.MkdirAll(dir, 0755)
			fileName := fmt.Sprintf("photo_%d_%d%s", now.UnixNano(), i, ext)
			dst := filepath.Join(dir, fileName)
			if err := saveFile(fh, dst); err == nil {
				relPath := fmt.Sprintf("reports/photos/%s/%s/%s", yearMonth, reporterID, fileName)
				photoPaths = append(photoPaths, baseURL+"/"+relPath)
			}
		}

		// Process audio (max 1, max 5 MB)
		if audioFiles := form.File["audio"]; len(audioFiles) > 0 {
			fh := audioFiles[0]
			if fh.Size <= 5<<20 {
				dir := filepath.Join(uploadDir, "reports", "audio", yearMonth, reporterID)
				_ = os.MkdirAll(dir, 0755)
				fileName := fmt.Sprintf("audio_%d.m4a", now.UnixNano())
				dst := filepath.Join(dir, fileName)
				if err := saveFile(fh, dst); err == nil {
					relPath := fmt.Sprintf("reports/audio/%s/%s/%s", yearMonth, reporterID, fileName)
					fullURL := baseURL + "/" + relPath
					audioPath = &fullURL
				}
			}
		}
	}

	rep, err := h.svc.CreateReport(reporterID, &req, photoPaths, audioPath)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error())
	}

	return utils.CreatedResponse(c, rep)
}

// GET /api/v1/reports/my — riwayat laporan milik user yang sedang login
func (h *Handler) GetMyReports(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	reports, err := h.svc.GetReportsByUser(userID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, reports)
}

// GET /api/v1/reports
func (h *Handler) GetReports(c *fiber.Ctx) error {
	status := c.Query("status", "")
	reports, err := h.svc.GetReports(status)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, reports)
}

// PATCH /api/v1/reports/:id/status
func (h *Handler) UpdateReportStatus(c *fiber.Ctx) error {
	id := c.Params("id")
	var body struct {
		Status string `json:"status"`
	}
	if err := c.BodyParser(&body); err != nil || body.Status == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Status wajib diisi")
	}
	if err := h.svc.UpdateReportStatus(id, body.Status); err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, fiber.Map{"updated": true})
}

// ─── helpers ──────────────────────────────────────────────────────────────────

func determineTrustLabel(c *fiber.Ctx) string {
	isEmailVerified, _ := c.Locals("isEmailVerified").(bool)
	isPhoneVerified, _ := c.Locals("isPhoneVerified").(bool)
	hasNIK, _ := c.Locals("hasNIK").(bool)

	if hasNIK && isPhoneVerified {
		return "verified"
	}
	if isEmailVerified || isPhoneVerified {
		return "standard"
	}
	return "unverified"
}

func isBanError(err error) bool {
	return err != nil && len(err.Error()) >= 10 && err.Error()[:10] == "sos_banned"
}

// broadcastSOSViaREST dipanggil dari REST handler setelah PromoteToBroadcasting.
// Mengambil koordinat dari DB lalu mengirim INCOMING_EMERGENCY ke agency & volunteer online.
func (h *Handler) broadcastSOSViaREST(incidentID string) {
	if h.hub == nil {
		return
	}

	// Ambil data incident dari DB
	inc, err := h.svc.repo.FindByID(incidentID)
	if err != nil || inc == nil {
		log.Printf("[IncidentHandler] broadcastSOSViaREST: incident %s not found: %v", incidentID, err)
		return
	}

	msg := hub.Message{
		Event: "INCOMING_EMERGENCY",
		Payload: map[string]interface{}{
			"incident_id": incidentID,
			"reporter_id": inc.ReporterID,
			"latitude":    inc.Latitude,
			"longitude":   inc.Longitude,
			"incident_type": inc.IncidentType,
			"status":      inc.Status,
		},
	}

	// Broadcast ke semua user online yang bukan reporter:
	// cek role → kirim ke agency/admin/superadmin
	ctx := context.Background()
	sent := 0
	for _, userID := range h.hub.OnlineUsers() {
		if userID == inc.ReporterID {
			continue
		}
		// Cek role dari Redis cache dulu, fallback ke DB
		roleKey := fmt.Sprintf("user:role:%s", userID)
		role, _ := h.rdb.Get(ctx, roleKey).Result()
		if role == "" {
			// Cache belum ada — ambil dari DB dan simpan 1 jam
			h.svc.repo.db.Raw("SELECT role FROM users WHERE id = ?", userID).Scan(&role)
			if role != "" {
				h.rdb.Set(ctx, roleKey, role, time.Hour)
			}
		}
		if role == "agency" || role == "admin" || role == "superadmin" {
			if err := h.hub.SendToUser(userID, msg); err == nil {
				sent++
			}
		}
	}
	log.Printf("[IncidentHandler] REST-triggered SOS broadcast: incident %s → %d console users", incidentID, sent)
}


func saveFile(fh *multipart.FileHeader, dst string) error {
	src, err := fh.Open()
	if err != nil {
		return err
	}
	defer func() { _ = src.Close() }()
	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer func() { _ = out.Close() }()
	_, err = io.Copy(out, src)
	return err
}

func parseFloat(s string) float64 {
	var f float64
	_, _ = fmt.Sscanf(s, "%f", &f)
	return f
}

func parseInt(s string, defaultVal int) int {
	var i int
	if _, err := fmt.Sscanf(s, "%d", &i); err != nil {
		return defaultVal
	}
	return i
}
