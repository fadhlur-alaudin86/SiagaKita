package incident

import (
	"fmt"
	"io"
	"mime/multipart"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"siagakita-backend/internal/config"
	"siagakita-backend/internal/hub"
	"siagakita-backend/internal/i18n"
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
	handler := &Handler{svc: svc, cfg: cfg, hub: h, rdb: rdb}
	// Wire callback: saat service auto-promote grace_period → broadcasting,
	// broadcast via WS ke console agar alarm berbunyi.
	svc.OnBroadcast = func(incidentID string) {
		go handler.broadcastSOSViaREST(incidentID)
	}
	return handler
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

	resp, err := h.svc.TriggerSOS(reporterID, &req)
	if err != nil {
		if isBanError(err) {
			return utils.ErrorResponse(c, fiber.StatusForbidden, err.Error())
		}
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	resp.Message = i18n.T(c, resp.Message)

	return utils.CreatedResponse(c, resp)
}

// PATCH /api/v1/incidents/:id/type - pilih tipe di grace period
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

// POST /api/v1/incidents/:id/broadcast - grace period timeout, tipe tetap 'unknown'
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

// POST /api/v1/incidents/:id/canceled
func (h *Handler) CancelSOS(c *fiber.Ctx) error {
	reporterID := c.Locals("userID").(string)
	incidentID := c.Params("id")

	if err := h.svc.CancelSOS(incidentID, reporterID); err != nil {
		status := fiber.StatusInternalServerError
		if err.Error() == "unauthorized" {
			status = fiber.StatusForbidden
		} else if len(err.Error()) >= 8 && err.Error()[:8] == "conflict" {
			status = fiber.StatusConflict
		}
		return utils.ErrorResponse(c, status, err.Error())
	}

	go h.broadcastEventToAgencies(hub.Message{
		Event: "SOS_CANCELLED",
		Payload: map[string]interface{}{
			"incident_id": incidentID,
		},
	})

	return utils.SuccessResponse(c, fiber.Map{"canceled": true})
}

// POST /api/v1/incidents/:id/evidence
// Menerima foto kamera depan (1 file) dan audio (1 file, max 5 detik) sebagai bukti situasi SOS.
// Dipanggil secara background SETELAH insiden masuk fase broadcasting.
func (h *Handler) UploadEvidence(c *fiber.Ctx) error {
	reporterID := c.Locals("userID").(string)
	incidentID := c.Params("id")

	uploadDir := h.cfg.UploadDir
	baseURL := h.cfg.UploadBaseURL
	now := time.Now()
	yearMonth := fmt.Sprintf("%d/%02d", now.Year(), now.Month())

	var photoPaths []string
	var audioPath *string

	form, err := c.MultipartForm()
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Form tidak valid")
	}

	// Foto kamera (depan + belakang, max 5 MB per file)
	if photos := form.File["photo"]; len(photos) > 0 {
		for i, fh := range photos {
			if fh.Size <= 5<<20 {
				ext := filepath.Ext(fh.Filename)
				if ext == "" {
					ext = ".jpg"
				}
				dir := filepath.Join(uploadDir, "incidents", "evidence", yearMonth, incidentID)
				_ = os.MkdirAll(dir, 0755)
				fileName := fmt.Sprintf("evidence_photo_%d_%d%s", now.UnixNano(), i, ext)
				dst := filepath.Join(dir, fileName)
				if saveErr := saveFile(fh, dst); saveErr == nil {
					relPath := fmt.Sprintf("incidents/evidence/%s/%s/%s", yearMonth, incidentID, fileName)
					photoPaths = append(photoPaths, baseURL+"/"+relPath)
				}
			}
		}
	}

	// Audio bukti (max 1, max 10 MB)
	if audios := form.File["audio"]; len(audios) > 0 {
		fh := audios[0]
		if fh.Size <= 10<<20 {
			dir := filepath.Join(uploadDir, "incidents", "evidence", yearMonth, incidentID)
			_ = os.MkdirAll(dir, 0755)
			fileName := fmt.Sprintf("evidence_audio_%d.m4a", now.UnixNano())
			dst := filepath.Join(dir, fileName)
			if saveErr := saveFile(fh, dst); saveErr == nil {
				relPath := fmt.Sprintf("incidents/evidence/%s/%s/%s", yearMonth, incidentID, fileName)
				path := baseURL + "/" + relPath
				audioPath = &path
			}
		}
	}

	if err := h.svc.UploadEvidence(incidentID, reporterID, photoPaths, audioPath); err != nil {
		status := fiber.StatusInternalServerError
		if err.Error() == "unauthorized" {
			status = fiber.StatusForbidden
		}
		return utils.ErrorResponse(c, status, err.Error())
	}

	// Notifikasi ke console agar foto/audio baru langsung terlihat
	go h.broadcastEventToAgencies(hub.Message{
		Event: "SOS_STATUS_UPDATE",
		Payload: map[string]interface{}{
			"incident_id": incidentID,
		},
	})

	return utils.SuccessResponse(c, fiber.Map{"evidence_uploaded": true})
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

	go h.broadcastEventToAgencies(hub.Message{
		Event: "LOCATION_UPDATE",
		Payload: map[string]interface{}{
			"incident_id": incidentID,
			"latitude":    req.Latitude,
			"longitude":   req.Longitude,
			"updated_at":  time.Now().Format(time.RFC3339),
		},
	})

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

// GET /api/v1/incidents/all-active - untuk console desktop (agency/admin)
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
	resp.Message = i18n.T(c, resp.Message)

	go h.broadcastEventToAgencies(hub.Message{
		Event: "SOS_STATUS_UPDATE",
		Payload: map[string]interface{}{
			"incident_id": incidentID,
		},
	})

	// Notifikasi ke reporter (mobile) agar SOS reset dan vibration berhenti
	go h.notifyReporter(incidentID, "SOS_FALSE_ALARM", map[string]interface{}{
		"incident_id": incidentID,
	})

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

// POST /api/v1/reports - Jalur B laporan warga (multipart/form-data)
func (h *Handler) CreateReport(c *fiber.Ctx) error {
	reporterID := c.Locals("userID").(string)

	// Parse form fields (works for both multipart and url-encoded)
	req := CreateReportRequest{
		IncidentType:  c.FormValue("incident_type"),
		Description:   c.FormValue("description"),
		Latitude:      parseFloat(c.FormValue("latitude")),
		Longitude:     parseFloat(c.FormValue("longitude")),
		AddressDetail: c.FormValue("address_detail"),
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

// POST /api/v1/reports/:id/canceled - membatalkan laporan warga
func (h *Handler) CancelReport(c *fiber.Ctx) error {
	reporterID := c.Locals("userID").(string)
	reportID := c.Params("id")

	if err := h.svc.CancelReport(reportID, reporterID); err != nil {
		status := fiber.StatusInternalServerError
		if err.Error() == "unauthorized" {
			status = fiber.StatusForbidden
		} else if err.Error() == "laporan tidak ditemukan" {
			status = fiber.StatusNotFound
		} else if err.Error() == "hanya laporan dengan status 'sent' atau 'pending' yang dapat dibatalkan" {
			status = fiber.StatusConflict
		}
		return utils.ErrorResponse(c, status, err.Error())
	}

	return utils.SuccessResponse(c, fiber.Map{"canceled": true})
}

// GET /api/v1/reports/my - riwayat laporan milik user yang sedang login
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
		Status       string `json:"status"`
		UrgencyLevel *int   `json:"urgency_level"`
	}
	if err := c.BodyParser(&body); err != nil || body.Status == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Status wajib diisi")
	}
	if err := h.svc.UpdateReportStatus(id, body.Status, body.UrgencyLevel); err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, fiber.Map{"updated": true})
}

// GET /api/v1/incidents/agency/history
func (h *Handler) GetAgencyHistory(c *fiber.Ctx) error {
	incidents, err := h.svc.GetAgencyHistory()
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.SuccessResponse(c, incidents)
}

// ─── helpers ──────────────────────────────────────────────────────────────────

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
		utils.Error().Err(err).Str("incident_id", incidentID).Msg("[IncidentHandler] broadcastSOSViaREST: incident not found")
		return
	}

	msg := hub.Message{
		Event: "INCOMING_EMERGENCY",
		Payload: map[string]interface{}{
			"incident_id":   incidentID,
			"reporter_id":   inc.ReporterID,
			"latitude":      inc.Latitude,
			"longitude":     inc.Longitude,
			"incident_type": inc.IncidentType,
			"status":        inc.Status,
		},
	}

	// Broadcast ke semua role console (agency, admin, superadmin) yang bukan reporter
	sent := 0
	if h.hub != nil {
		sent = h.hub.BroadcastToRoles(msg, inc.ReporterID, "agency", "admin", "superadmin")
	}
	utils.Info().Str("incident_id", incidentID).Int("sent_count", sent).Msg("[IncidentHandler] REST-triggered SOS broadcast")
}

func (h *Handler) broadcastEventToAgencies(msg hub.Message) {
	if h.hub == nil {
		return
	}
	h.hub.BroadcastToRoles(msg, "", "agency", "admin", "superadmin")
}

// notifyReporter mengirimkan WS event ke user yang membuat SOS (reporter).
// Digunakan untuk memberi tahu real-time saat agency atau relawan mulai menangani.
func (h *Handler) notifyReporter(incidentID, event string, payload map[string]interface{}) {
	if h.hub == nil {
		return
	}
	inc, err := h.svc.repo.FindByID(incidentID)
	if err != nil || inc == nil {
		utils.Error().Err(err).Str("incident_id", incidentID).Msg("[Handler] notifyReporter: incident not found")
		return
	}
	_ = h.hub.SendToUser(inc.ReporterID, hub.Message{
		Event:   event,
		Payload: payload,
	})
}

// GET /api/v1/incidents/nearby?lat=&lng=&radius=5
// Hanya untuk volunteer - mengembalikan SOS aktif dalam radius tertentu.
func (h *Handler) GetNearby(c *fiber.Ctx) error {
	volunteerID := c.Locals("userID").(string)
	latStr := c.Query("lat")
	lngStr := c.Query("lng")
	radiusStr := c.Query("radius", "5")

	lat, err := strconv.ParseFloat(latStr, 64)
	if err != nil || lat == 0 {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Parameter 'lat' wajib diisi dan harus berupa angka")
	}
	lng, err := strconv.ParseFloat(lngStr, 64)
	if err != nil || lng == 0 {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Parameter 'lng' wajib diisi dan harus berupa angka")
	}
	radius, err := strconv.ParseFloat(radiusStr, 64)
	if err != nil || radius <= 0 {
		radius = 5.0
	}
	if radius > 50 {
		radius = 50.0 // maksimal 50km
	}

	results, err := h.svc.GetNearby(lat, lng, radius, volunteerID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Gagal mengambil data SOS terdekat")
	}

	return utils.SuccessResponse(c, results)
}

// POST /api/v1/incidents/:id/accept
// Relawan menerima SOS dan siap menuju lokasi.
func (h *Handler) AcceptSOS(c *fiber.Ctx) error {
	volunteerID := c.Locals("userID").(string)
	incidentID := c.Params("id")

	if incidentID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "ID insiden wajib diisi")
	}

	result, err := h.svc.AcceptIncident(incidentID, volunteerID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusConflict, err.Error())
	}
	result.Message = i18n.T(c, result.Message)

	go func() {
		h.broadcastEventToAgencies(hub.Message{
			Event:   "SOS_STATUS_UPDATE",
			Payload: map[string]interface{}{"incident_id": incidentID},
		})
		// Notify reporter bahwa relawan sudah on the way
		h.notifyReporter(incidentID, "VOLUNTEER_HANDLING", map[string]interface{}{
			"incident_id":      incidentID,
			"volunteer_status": "en_route",
		})
	}()

	return utils.SuccessResponse(c, result)
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

// ─── Lanjutan Gamifikasi & Review ───────────────────────────────────────────

// POST /api/v1/incidents/:id/agency-handle [ConsoleOnly]
func (h *Handler) AgencyHandleSOS(c *fiber.Ctx) error {
	agencyID := c.Locals("userID").(string)
	incidentID := c.Params("id")

	if err := h.svc.AgencyHandleSOS(incidentID, agencyID); err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Gagal menangani SOS: "+err.Error())
	}

	go func() {
		h.broadcastEventToAgencies(hub.Message{
			Event:   "SOS_STATUS_UPDATE",
			Payload: map[string]interface{}{"incident_id": incidentID},
		})
		h.hub.BroadcastToRole("agency", hub.Message{
			Event:   "INCIDENT_UPDATED",
			Payload: map[string]interface{}{"incident_id": incidentID, "action": "agency_handle"},
		})
		h.hub.BroadcastToRole("admin", hub.Message{
			Event:   "INCIDENT_UPDATED",
			Payload: map[string]interface{}{"incident_id": incidentID, "action": "agency_handle"},
		})
		h.hub.BroadcastToRole("superadmin", hub.Message{
			Event:   "INCIDENT_UPDATED",
			Payload: map[string]interface{}{"incident_id": incidentID, "action": "agency_handle"},
		})
		// Notify reporter bahwa instansi sudah handle
		h.notifyReporter(incidentID, "AGENCY_HANDLING", map[string]interface{}{
			"incident_id":   incidentID,
			"agency_status": "handling",
		})
	}()

	return utils.SuccessResponse(c, fiber.Map{"message": "SOS sekarang ditangani instansi."})
}

// POST /api/v1/incidents/:id/volunteer-complete [VolunteerOnly] (Multipart)
func (h *Handler) VolunteerCompleteSOS(c *fiber.Ctx) error {
	volunteerID := c.Locals("userID").(string)
	incidentID := c.Params("id")

	form, err := c.MultipartForm()
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Form tidak valid")
	}

	var photoPaths []string
	if photos := form.File["photo"]; len(photos) > 0 {
		fh := photos[0]
		if fh.Size <= 5<<20 {
			ext := filepath.Ext(fh.Filename)
			if ext == "" {
				ext = ".jpg"
			}
			now := time.Now()
			yearMonth := fmt.Sprintf("%d/%02d", now.Year(), now.Month())
			dir := filepath.Join(h.cfg.UploadDir, "incidents", "volunteer_proofs", yearMonth, incidentID)
			_ = os.MkdirAll(dir, 0755)
			fileName := fmt.Sprintf("proof_%d%s", now.UnixNano(), ext)
			dst := filepath.Join(dir, fileName)

			if err := saveFile(fh, dst); err == nil {
				publicURL := fmt.Sprintf("%s/incidents/volunteer_proofs/%s/%s/%s", h.cfg.UploadBaseURL, yearMonth, incidentID, fileName)
				photoPaths = append(photoPaths, publicURL)
			}
		}
	}

	if err := h.svc.VolunteerCompleteSOS(incidentID, volunteerID, photoPaths); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error())
	}

	go func() {
		h.broadcastEventToAgencies(hub.Message{
			Event:   "SOS_STATUS_UPDATE",
			Payload: map[string]interface{}{"incident_id": incidentID},
		})
		h.hub.BroadcastToRole("agency", hub.Message{
			Event:   "INCIDENT_UPDATED",
			Payload: map[string]interface{}{"incident_id": incidentID, "action": "volunteer_complete"},
		})
		h.hub.BroadcastToRole("admin", hub.Message{
			Event:   "INCIDENT_UPDATED",
			Payload: map[string]interface{}{"incident_id": incidentID, "action": "volunteer_complete"},
		})
		h.hub.BroadcastToRole("superadmin", hub.Message{
			Event:   "INCIDENT_UPDATED",
			Payload: map[string]interface{}{"incident_id": incidentID, "action": "volunteer_complete"},
		})
	}()

	return utils.SuccessResponse(c, fiber.Map{"message": "Bukti berhasil diunggah. Menunggu review instansi."})
}

// POST /api/v1/incidents/:id/agency-review [ConsoleOnly]
func (h *Handler) AgencyReviewVolunteer(c *fiber.Ctx) error {
	incidentID := c.Params("id")

	var req struct {
		VolunteerID string `json:"volunteer_id"`
		Approve     bool   `json:"approve"`
	}
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}

	resp, err := h.svc.AgencyReviewVolunteer(incidentID, req.VolunteerID, req.Approve)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}

	go func() {
		h.broadcastEventToAgencies(hub.Message{
			Event:   "SOS_STATUS_UPDATE",
			Payload: map[string]interface{}{"incident_id": incidentID},
		})
		h.hub.BroadcastToRole("agency", hub.Message{
			Event:   "INCIDENT_UPDATED",
			Payload: map[string]interface{}{"incident_id": incidentID, "action": "agency_review"},
		})
		h.hub.BroadcastToRole("admin", hub.Message{
			Event:   "INCIDENT_UPDATED",
			Payload: map[string]interface{}{"incident_id": incidentID, "action": "agency_review"},
		})
		h.hub.BroadcastToRole("superadmin", hub.Message{
			Event:   "INCIDENT_UPDATED",
			Payload: map[string]interface{}{"incident_id": incidentID, "action": "agency_review"},
		})
	}()

	return utils.SuccessResponse(c, resp)
}

// POST /api/v1/incidents/:id/agency-resolve [ConsoleOnly]
func (h *Handler) AgencyResolveSOS(c *fiber.Ctx) error {
	incidentID := c.Params("id")
	resp, err := h.svc.AgencyResolveSOS(incidentID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}

	go func() {
		h.broadcastEventToAgencies(hub.Message{
			Event:   "SOS_STATUS_UPDATE",
			Payload: map[string]interface{}{"incident_id": incidentID},
		})
		h.hub.BroadcastToRole("agency", hub.Message{
			Event:   "INCIDENT_UPDATED",
			Payload: map[string]interface{}{"incident_id": incidentID, "action": "resolved"},
		})
		h.hub.BroadcastToRole("admin", hub.Message{
			Event:   "INCIDENT_UPDATED",
			Payload: map[string]interface{}{"incident_id": incidentID, "action": "resolved"},
		})
		h.hub.BroadcastToRole("superadmin", hub.Message{
			Event:   "INCIDENT_UPDATED",
			Payload: map[string]interface{}{"incident_id": incidentID, "action": "resolved"},
		})
	}()

	return utils.SuccessResponse(c, resp)
}

// GET /api/v1/incidents/my-history [VolunteerOnly]
func (h *Handler) GetMissionHistory(c *fiber.Ctx) error {
	volunteerID := c.Locals("userID").(string)

	history, err := h.svc.GetMissionHistory(volunteerID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Gagal memuat riwayat misi")
	}

	return utils.SuccessResponse(c, history)
}

// GET /api/v1/incidents/my-active-response [VolunteerOnly]
func (h *Handler) GetMyActiveResponse(c *fiber.Ctx) error {
	volunteerID := c.Locals("userID").(string)
	resp, err := h.svc.GetActiveResponse(volunteerID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Gagal memuat misi aktif")
	}
	return utils.SuccessResponse(c, resp)
}

// PUT /api/v1/incidents/:id/response-location [VolunteerOnly]
func (h *Handler) UpdateResponseLocation(c *fiber.Ctx) error {
	volunteerID := c.Locals("userID").(string)
	incidentID := c.Params("id")

	var req UpdateResponseLocationRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}

	if err := h.svc.UpdateResponseLocation(incidentID, volunteerID, req.Latitude, req.Longitude, req.AddressDetail); err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}

	// Broadcast lokasi relawan ke agency dan reporter via WebSocket
	go func() {
		payload := map[string]interface{}{
			"incident_id":  incidentID,
			"volunteer_id": volunteerID,
			"latitude":     req.Latitude,
			"longitude":    req.Longitude,
			"updated_at":   time.Now().Format(time.RFC3339),
		}
		if req.AddressDetail != nil {
			payload["address_detail"] = *req.AddressDetail
		}
		h.broadcastEventToAgencies(hub.Message{
			Event:   "VOLUNTEER_LOCATION_UPDATE",
			Payload: payload,
		})
		h.notifyReporter(incidentID, "VOLUNTEER_LOCATION_UPDATE", payload)
	}()

	return utils.SuccessResponse(c, fiber.Map{"updated": true})
}
