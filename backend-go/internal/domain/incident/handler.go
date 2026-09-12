package incident

import (
	"context"
	"errors"
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
	svc                     *Service
	cfg                     *config.Config
	hub                     *hub.Hub
	rdb                     *redis.Client
	OnPushEmergency         func(incidentID, incidentType, address, reporterID string, lat, lon float64)
	OnPushMissionAssignment func(personnelUserID, incidentID, incidentType, address string, lat, lon float64)
}

func NewHandler(svc *Service, cfg *config.Config, h *hub.Hub, rdb *redis.Client) *Handler {
	handler := &Handler{svc: svc, cfg: cfg, hub: h, rdb: rdb}
	// Wire callback: saat service auto-promote grace_period → broadcasting,
	// broadcast via WS ke console agar alarm berbunyi.
	svc.OnBroadcast = func(incidentID string) {
		go handler.broadcastSOSViaREST(incidentID)
	}
	// Wire callback: saat relawan mendapatkan badge tier baru,
	// kirim event WS BADGE_UNLOCKED ke user.
	svc.OnBadgeUnlocked = func(userID string, badges []BadgeUnlocked) {
		if handler.hub != nil {
			_ = handler.hub.SendToUser(userID, hub.Message{
				Event:   "BADGE_UNLOCKED",
				Payload: fiber.Map{"badges": badges},
			})
		}
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
		if errors.Is(err, ErrUnauthorized) {
			status = fiber.StatusForbidden
		}
		return utils.ErrorResponse(c, status, err.Error())
	}

	// Broadcast via WS setelah tipe diubah dan status menjadi broadcasting
	go h.broadcastSOSViaREST(incidentID)

	return utils.SuccessResponse(c, fiber.Map{FieldUpdated: true, FieldMessage: "Tipe insiden diperbarui, SOS sedang disiarkan."})
}

// POST /api/v1/incidents/:id/broadcast - grace period timeout, tipe tetap 'unknown'
func (h *Handler) Broadcast(c *fiber.Ctx) error {
	reporterID := c.Locals("userID").(string)
	incidentID := c.Params("id")

	if err := h.svc.PromoteToBroadcasting(incidentID, reporterID); err != nil {
		status := fiber.StatusInternalServerError
		if errors.Is(err, ErrUnauthorized) {
			status = fiber.StatusForbidden
		}
		return utils.ErrorResponse(c, status, err.Error())
	}

	// Broadcast via WS setelah grace period berakhir (dipanggil dari REST)
	go h.broadcastSOSViaREST(incidentID)

	return utils.SuccessResponse(c, fiber.Map{"broadcasting": true, FieldMessage: "SOS sedang disiarkan ke relawan dan instansi terdekat."})
}

// POST /api/v1/incidents/:id/canceled
func (h *Handler) CancelSOS(c *fiber.Ctx) error {
	reporterID := c.Locals("userID").(string)
	incidentID := c.Params("id")

	if err := h.svc.CancelSOS(incidentID, reporterID); err != nil {
		status := fiber.StatusInternalServerError
		if errors.Is(err, ErrUnauthorized) {
			status = fiber.StatusForbidden
		} else if errors.Is(err, ErrIncidentConflict) {
			status = fiber.StatusConflict
		}
		return utils.ErrorResponse(c, status, err.Error())
	}

	go h.broadcastEventToAgencies(hub.Message{
		Event: "SOS_CANCELLED",
		Payload: map[string]interface{}{
			FieldIncidentID: incidentID,
		},
	})

	return utils.SuccessResponse(c, fiber.Map{StatusCanceled: true})
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
					ext = extJPG
				}
				dir := filepath.Join(uploadDir, "incidents", "evidence", yearMonth, incidentID)
				_ = os.MkdirAll(dir, 0750)
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
			_ = os.MkdirAll(dir, 0750)
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
		if errors.Is(err, ErrUnauthorized) {
			status = fiber.StatusForbidden
		}
		return utils.ErrorResponse(c, status, err.Error())
	}

	// Notifikasi ke console agar foto/audio baru langsung terlihat
	go h.broadcastEventToAgencies(hub.Message{
		Event: EventSOSStatusUpdate,
		Payload: map[string]interface{}{
			FieldIncidentID: incidentID,
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
			FieldIncidentID: incidentID,
			FieldLatitude:   req.Latitude,
			FieldLongitude:  req.Longitude,
			FieldUpdatedAt:  time.Now().Format(time.RFC3339),
		},
	})

	return utils.SuccessResponse(c, fiber.Map{FieldUpdated: true})
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
			FieldIncidentID: incidentID,
		},
	})

	// Notifikasi ke reporter (mobile) agar SOS reset dan vibration berhenti
	go h.notifyReporter(incidentID, "SOS_FALSE_ALARM", map[string]interface{}{
		FieldIncidentID: incidentID,
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

func parseReportRequest(c *fiber.Ctx) (*CreateReportRequest, string) {
	req := CreateReportRequest{
		IncidentType:  c.FormValue("incident_type"),
		Description:   c.FormValue("description"),
		Latitude:      parseFloat(c.FormValue("latitude")),
		Longitude:     parseFloat(c.FormValue("longitude")),
		AddressDetail: c.FormValue("address_detail"),
	}

	if req.IncidentType == "" || req.IncidentType == IncidentTypeUnknown {
		return nil, "incident_type wajib diisi"
	}
	if req.Latitude == 0 && req.Longitude == 0 {
		return nil, "Koordinat GPS wajib diisi"
	}

	return &req, ""
}

func processReportPhotos(photos []*multipart.FileHeader, uploadDir, baseURL, reporterID, yearMonth string, now time.Time) []string {
	if len(photos) > 3 {
		photos = photos[:3]
	}
	var photoPaths []string
	for i, fh := range photos {
		if fh.Size > 2<<20 {
			continue
		}
		ext := filepath.Ext(fh.Filename)
		if ext == "" {
			ext = extJPG
		}
		// Use reporterID as temp dir key before report is created
		dir := filepath.Join(uploadDir, "reports", "photos", yearMonth, reporterID)
		_ = os.MkdirAll(dir, 0750)
		fileName := fmt.Sprintf("photo_%d_%d%s", now.UnixNano(), i, ext)
		dst := filepath.Join(dir, fileName)
		if err := saveFile(fh, dst); err == nil {
			relPath := fmt.Sprintf("reports/photos/%s/%s/%s", yearMonth, reporterID, fileName)
			photoPaths = append(photoPaths, baseURL+"/"+relPath)
		}
	}
	return photoPaths
}

func processReportAudio(audioFiles []*multipart.FileHeader, uploadDir, baseURL, reporterID, yearMonth string, now time.Time) *string {
	if len(audioFiles) == 0 {
		return nil
	}
	fh := audioFiles[0]
	if fh.Size > 5<<20 {
		return nil
	}
	dir := filepath.Join(uploadDir, "reports", "audio", yearMonth, reporterID)
	_ = os.MkdirAll(dir, 0750)
	fileName := fmt.Sprintf("audio_%d.m4a", now.UnixNano())
	dst := filepath.Join(dir, fileName)
	if err := saveFile(fh, dst); err == nil {
		relPath := fmt.Sprintf("reports/audio/%s/%s/%s", yearMonth, reporterID, fileName)
		fullURL := baseURL + "/" + relPath
		return &fullURL
	}
	return nil
}

// POST /api/v1/reports - Jalur B laporan warga (multipart/form-data)
func (h *Handler) CreateReport(c *fiber.Ctx) error {
	reporterID := c.Locals("userID").(string)

	req, errMsg := parseReportRequest(c)
	if errMsg != "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, errMsg)
	}

	var photoPaths []string
	var audioPath *string

	if form, err := c.MultipartForm(); err == nil {
		now := time.Now()
		yearMonth := fmt.Sprintf("%d/%02d", now.Year(), now.Month())
		photoPaths = processReportPhotos(form.File["photos[]"], h.cfg.UploadDir, h.cfg.UploadBaseURL, reporterID, yearMonth, now)
		audioPath = processReportAudio(form.File["audio"], h.cfg.UploadDir, h.cfg.UploadBaseURL, reporterID, yearMonth, now)
	}

	rep, err := h.svc.CreateReport(reporterID, req, photoPaths, audioPath)
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
		if errors.Is(err, ErrUnauthorized) {
			status = fiber.StatusForbidden
		} else if errors.Is(err, ErrReportNotFound) {
			status = fiber.StatusNotFound
		} else if errors.Is(err, ErrReportCannotBeCanceled) {
			status = fiber.StatusConflict
		}
		return utils.ErrorResponse(c, status, err.Error())
	}

	return utils.SuccessResponse(c, fiber.Map{StatusCanceled: true})
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
	return utils.SuccessResponse(c, fiber.Map{FieldUpdated: true})
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
	return errors.Is(err, ErrSOSBanned)
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
			FieldIncidentID:   incidentID,
			"reporter_id":     inc.ReporterID,
			FieldLatitude:     inc.Latitude,
			FieldLongitude:    inc.Longitude,
			FieldIncidentType: inc.IncidentType,
			FieldStatus:       inc.Status,
		},
	}

	// Broadcast ke semua role console (agency, admin, superadmin) yang bukan reporter
	sent := 0
	if h.hub != nil {
		sent = h.hub.BroadcastToRoles(msg, inc.ReporterID, "agency", "admin", "superadmin")
	}
	utils.Info().Str("incident_id", incidentID).Int("sent_count", sent).Msg("[IncidentHandler] REST-triggered SOS broadcast")

	// Trigger push notification broadcast ke relawan dan responder terdekat
	if h.OnPushEmergency != nil {
		addr := ""
		if inc.AddressDetail != nil {
			addr = *inc.AddressDetail
		}
		go h.OnPushEmergency(inc.ID, inc.IncidentType, addr, inc.ReporterID, inc.Latitude, inc.Longitude)
	}
}

func (h *Handler) broadcastEventToAgencies(msg hub.Message) {
	if h.hub == nil {
		return
	}
	h.hub.BroadcastToRoles(msg, "", "agency", "admin", "superadmin", "agency_personnel")
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
			Payload: map[string]interface{}{FieldIncidentID: incidentID},
		})
		// Notify reporter bahwa relawan sudah on the way
		h.notifyReporter(incidentID, "VOLUNTEER_HANDLING", map[string]interface{}{
			FieldIncidentID:    incidentID,
			"volunteer_status": "en_route",
		})
		// Notify candidate volunteers that the incident has been claimed
		if h.rdb != nil && h.hub != nil {
			ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
			defer cancel()
			key := "dispatch:incident:" + incidentID + ":volunteers"
			volunteers, _ := h.rdb.SMembers(ctx, key).Result()
			for _, vID := range volunteers {
				if vID != volunteerID {
					_ = h.hub.SendToUser(vID, hub.Message{
						Event: "INCIDENT_ASSIGNMENT_CLAIMED",
						Payload: map[string]interface{}{
							FieldIncidentID: incidentID,
							"claimed_by":    volunteerID,
						},
					})
				}
			}
			_ = h.rdb.Del(ctx, key)
		}
	}()

	return utils.SuccessResponse(c, result)
}

func saveFile(fh *multipart.FileHeader, dst string) error {
	src, err := fh.Open()
	if err != nil {
		return err
	}
	defer func() { _ = src.Close() }()
	//nolint:gosec // G304: destination path is constructed via filepath.Join with server-generated filenames
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
			Event:   EventSOSStatusUpdate,
			Payload: map[string]interface{}{FieldIncidentID: incidentID},
		})
		h.hub.BroadcastToRole("agency", hub.Message{
			Event:   EventIncidentUpdated,
			Payload: map[string]interface{}{FieldIncidentID: incidentID, FieldAction: ActionAgencyHandle},
		})
		h.hub.BroadcastToRole("admin", hub.Message{
			Event:   EventIncidentUpdated,
			Payload: map[string]interface{}{FieldIncidentID: incidentID, FieldAction: ActionAgencyHandle},
		})
		h.hub.BroadcastToRole("superadmin", hub.Message{
			Event:   EventIncidentUpdated,
			Payload: map[string]interface{}{FieldIncidentID: incidentID, FieldAction: ActionAgencyHandle},
		})
		// Notify reporter bahwa instansi sudah handle
		h.notifyReporter(incidentID, "AGENCY_HANDLING", map[string]interface{}{
			FieldIncidentID:   incidentID,
			FieldAgencyStatus: AgencyStatusHandling,
		})
	}()

	return utils.SuccessResponse(c, fiber.Map{FieldMessage: "SOS sekarang ditangani instansi."})
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
				ext = extJPG
			}
			now := time.Now()
			yearMonth := fmt.Sprintf("%d/%02d", now.Year(), now.Month())
			dir := filepath.Join(h.cfg.UploadDir, "incidents", "volunteer_proofs", yearMonth, incidentID)
			_ = os.MkdirAll(dir, 0750)
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
			Event:   EventSOSStatusUpdate,
			Payload: map[string]interface{}{FieldIncidentID: incidentID},
		})
		h.hub.BroadcastToRole("agency", hub.Message{
			Event:   EventIncidentUpdated,
			Payload: map[string]interface{}{FieldIncidentID: incidentID, FieldAction: ActionVolunteerComplete},
		})
		h.hub.BroadcastToRole("admin", hub.Message{
			Event:   EventIncidentUpdated,
			Payload: map[string]interface{}{FieldIncidentID: incidentID, FieldAction: ActionVolunteerComplete},
		})
		h.hub.BroadcastToRole("superadmin", hub.Message{
			Event:   EventIncidentUpdated,
			Payload: map[string]interface{}{FieldIncidentID: incidentID, FieldAction: ActionVolunteerComplete},
		})
	}()

	return utils.SuccessResponse(c, fiber.Map{FieldMessage: "Bukti berhasil diunggah. Menunggu review instansi."})
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
			Event:   EventSOSStatusUpdate,
			Payload: map[string]interface{}{FieldIncidentID: incidentID},
		})
		h.hub.BroadcastToRole("agency", hub.Message{
			Event:   EventIncidentUpdated,
			Payload: map[string]interface{}{FieldIncidentID: incidentID, FieldAction: ActionAgencyReview},
		})
		h.hub.BroadcastToRole("admin", hub.Message{
			Event:   EventIncidentUpdated,
			Payload: map[string]interface{}{FieldIncidentID: incidentID, FieldAction: ActionAgencyReview},
		})
		h.hub.BroadcastToRole("superadmin", hub.Message{
			Event:   EventIncidentUpdated,
			Payload: map[string]interface{}{FieldIncidentID: incidentID, FieldAction: ActionAgencyReview},
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
			Event:   EventSOSStatusUpdate,
			Payload: map[string]interface{}{FieldIncidentID: incidentID},
		})
		h.hub.BroadcastToRole("agency", hub.Message{
			Event:   EventIncidentUpdated,
			Payload: map[string]interface{}{FieldIncidentID: incidentID, FieldAction: ActionResolved},
		})
		h.hub.BroadcastToRole("admin", hub.Message{
			Event:   EventIncidentUpdated,
			Payload: map[string]interface{}{FieldIncidentID: incidentID, FieldAction: ActionResolved},
		})
		h.hub.BroadcastToRole("superadmin", hub.Message{
			Event:   EventIncidentUpdated,
			Payload: map[string]interface{}{FieldIncidentID: incidentID, FieldAction: ActionResolved},
		})
	}()

	return utils.SuccessResponse(c, resp)
}

// GET /api/v1/incidents/my-history [VolunteerOnly]
// GET /api/v1/incidents/missions/history [VolunteerOnly]
func (h *Handler) GetMissionHistory(c *fiber.Ctx) error {
	volunteerID := c.Locals("userID").(string)
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 20)

	history, err := h.svc.GetMissionHistoryPaginated(volunteerID, page, limit)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Gagal memuat riwayat misi")
	}

	return utils.SuccessResponse(c, history)
}

// GET /api/v1/volunteer/badges [VolunteerOnly]
func (h *Handler) GetVolunteerBadges(c *fiber.Ctx) error {
	volunteerID := c.Locals("userID").(string)

	badges, err := h.svc.GetVolunteerBadges(volunteerID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Gagal memuat badge relawan")
	}

	return utils.SuccessResponse(c, badges)
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
			FieldIncidentID: incidentID,
			"volunteer_id":  volunteerID,
			FieldLatitude:   req.Latitude,
			FieldLongitude:  req.Longitude,
			FieldUpdatedAt:  time.Now().Format(time.RFC3339),
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

	return utils.SuccessResponse(c, fiber.Map{FieldUpdated: true})
}

func isIncidentTerminal(status string) bool {
	return status == StatusResolved || status == StatusCanceled || status == StatusFalseAlarm
}

func (h *Handler) cacheDispatchCandidates(incidentID string, volunteerIDs []string) {
	if h.rdb == nil {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	key := "dispatch:incident:" + incidentID + ":volunteers"
	_ = h.rdb.Del(ctx, key)
	for _, vid := range volunteerIDs {
		_ = h.rdb.SAdd(ctx, key, vid)
	}
	_ = h.rdb.Expire(ctx, key, 120*time.Second)
}

func (h *Handler) handleDispatchTimeout(incidentID string, targetIDs []string) {
	time.Sleep(60 * time.Second)
	if h.rdb == nil {
		return
	}
	checkCtx, checkCancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer checkCancel()

	key := "dispatch:incident:" + incidentID + ":volunteers"
	exists, _ := h.rdb.Exists(checkCtx, key).Result()
	if exists > 0 {
		_ = h.rdb.Del(checkCtx, key)
		// Broadcast timeout event to console operators
		h.broadcastEventToAgencies(hub.Message{
			Event: "INCIDENT_DISPATCH_TIMEOUT",
			Payload: map[string]interface{}{
				FieldIncidentID: incidentID,
			},
		})
		// Notify candidate volunteers that offer timed out
		if h.hub != nil {
			for _, vid := range targetIDs {
				_ = h.hub.SendToUser(vid, hub.Message{
					Event: "INCIDENT_ASSIGNMENT_CLAIMED",
					Payload: map[string]interface{}{
						FieldIncidentID: incidentID,
						"reason":        "timeout",
					},
				})
			}
		}
	}
}

func (h *Handler) broadcastAssignmentOffers(incidentID string, inc *Incident, volunteerIDs []string) {
	if h.hub == nil {
		return
	}

	var address string
	if inc.AddressDetail != nil {
		address = *inc.AddressDetail
	}

	offerMsg := hub.Message{
		Event: "INCIDENT_ASSIGNMENT_OFFER",
		Payload: map[string]interface{}{
			FieldIncidentID:   incidentID,
			FieldIncidentType: inc.IncidentType,
			FieldLatitude:     inc.Latitude,
			FieldLongitude:    inc.Longitude,
			"address_detail":  address,
			"reporter_id":     inc.ReporterID,
			"timeout_seconds": 60,
			"offered_at":      time.Now().Unix(),
		},
	}

	for _, vid := range volunteerIDs {
		_ = h.hub.SendToUser(vid, offerMsg)
	}

	// 60-second timeout handler in goroutine
	go h.handleDispatchTimeout(incidentID, volunteerIDs)
}

// DispatchBroadcast handles POST /api/v1/incidents/:id/dispatch-broadcast [ConsoleOnly]
// Dispatches incident offers to selected candidate volunteers via WebSocket broadcast.
func (h *Handler) DispatchBroadcast(c *fiber.Ctx) error {
	incidentID := c.Params("id")
	if incidentID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "ID insiden wajib diisi")
	}

	var req struct {
		VolunteerIDs []string `json:"volunteer_ids"`
	}
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}
	if len(req.VolunteerIDs) == 0 {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Daftar volunteer_ids wajib diisi")
	}

	inc, err := h.svc.repo.FindByID(incidentID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusNotFound, "Insiden tidak ditemukan")
	}
	if isIncidentTerminal(inc.Status) {
		return utils.ErrorResponse(c, fiber.StatusConflict, "Insiden sudah ditangani atau selesai")
	}

	h.cacheDispatchCandidates(incidentID, req.VolunteerIDs)
	h.broadcastAssignmentOffers(incidentID, inc, req.VolunteerIDs)

	return utils.SuccessResponse(c, fiber.Map{
		FieldMessage: "Broadcast penugasan berhasil dikirim",
		"sent_to":    len(req.VolunteerIDs),
	})
}

// POST /api/v1/incidents/:id/personnel-status [PersonnelOnly / AgencyOrPersonnelOnly]
func (h *Handler) PersonnelUpdateStatus(c *fiber.Ctx) error {
	personnelID := c.Locals("userID").(string)
	incidentID := c.Params("id")

	var req struct {
		Status        string `json:"status"` // en_route, on_scene, resolved
		ProofPhotoURL string `json:"proof_photo_url,omitempty"`
	}
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}

	if req.Status == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Status wajib diisi")
	}

	if err := h.svc.PersonnelUpdateStatus(incidentID, personnelID, req.Status, req.ProofPhotoURL); err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error())
	}

	// Broadcast WS event ke agency console dan reporter
	go func() {
		h.broadcastEventToAgencies(hub.Message{
			Event: EventSOSStatusUpdate,
			Payload: map[string]interface{}{
				FieldIncidentID: incidentID,
				"personnel_id":  personnelID,
				"status":        req.Status,
			},
		})
		h.notifyReporter(incidentID, "AGENCY_HANDLING", map[string]interface{}{
			FieldIncidentID: incidentID,
			"status":        req.Status,
		})
	}()

	return utils.SuccessResponse(c, fiber.Map{
		"updated":    true,
		"status":     req.Status,
		FieldMessage: "Status misi berhasil diperbarui",
	})
}

// GET /api/v1/incidents/responder/active-mission [PersonnelOnly]
func (h *Handler) GetPersonnelActiveMission(c *fiber.Ctx) error {
	personnelID := c.Locals("userID").(string)
	resp, err := h.svc.GetActiveResponse(personnelID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Gagal memuat misi aktif")
	}
	return utils.SuccessResponse(c, resp)
}
