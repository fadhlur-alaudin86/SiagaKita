package ws

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"siagakita-backend/internal/config"
	"siagakita-backend/internal/domain/incident"
	"siagakita-backend/internal/hub"
	"siagakita-backend/internal/utils"

	"github.com/redis/go-redis/v9"
	"gorm.io/gorm"

	"github.com/gorilla/websocket"
)

const (
	relawanGeoKey    = "relawan:locations"
	incidentGraceKey = "incident:%s:grace"
	incidentLocKey   = "incident:%s:loc"
	gracePeriod      = 10 * time.Second
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin:     func(r *http.Request) bool { return true }, // TODO: restrict in production
}

// Handler is the WebSocket handler that processes real-time SOS events.
type Handler struct {
	hub     *hub.Hub
	rdb     *redis.Client
	db      *gorm.DB
	cfg     *config.Config
	incRepo *incident.Repository
}

// NewHandler creates a new WebSocket Handler.
func NewHandler(h *hub.Hub, rdb *redis.Client, db *gorm.DB, cfg *config.Config) *Handler {
	handler := &Handler{
		hub:     h,
		rdb:     rdb,
		db:      db,
		cfg:     cfg,
		incRepo: incident.NewRepository(db),
	}

	// Start the Redis expired-key subscriber goroutine
	handler.startExpiredKeySubscriber()
	return handler
}

// ServeWS is the net/http handler for WebSocket upgrade requests.
// Path: /v1/ws/connect
// Query: ?token=<jwt>   OR   Header: Authorization: Bearer <jwt>
func (h *Handler) ServeWS(w http.ResponseWriter, r *http.Request) {
	// Extract token from query param or header
	tokenStr := r.URL.Query().Get("token")
	if tokenStr == "" {
		auth := r.Header.Get("Authorization")
		if strings.HasPrefix(auth, "Bearer ") {
			tokenStr = strings.TrimPrefix(auth, "Bearer ")
		}
	}
	if tokenStr == "" {
		http.Error(w, "unauthorized: token missing", http.StatusUnauthorized)
		return
	}

	claims, err := utils.ParseToken(tokenStr, h.cfg.JWTSecret)
	if err != nil {
		http.Error(w, "unauthorized: invalid token", http.StatusUnauthorized)
		return
	}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		utils.Error().Err(err).Msg("[WS] Upgrade error")
		return
	}

	userID := claims.UserID
	// ConnID unik per koneksi WS — dibutuhkan untuk Unregister yang tepat
	// pada Hub multi-conn (console roles bisa punya banyak koneksi aktif).
	connID := fmt.Sprintf("%s-%s", userID, claims.JTI)

	h.hub.Register(userID, claims.Role, connID, conn)
	defer h.hub.Unregister(userID, connID)

	// Send welcome message
	_ = h.hub.SendToUser(userID, hub.Message{
		Event:   "CONNECTED",
		Payload: map[string]string{"user_id": userID, "message": "Terhubung ke SiagaKita real-time engine"},
	})

	h.readLoop(userID, conn)
}


// readLoop blocks and reads incoming messages from the client connection.
func (h *Handler) readLoop(userID string, conn *websocket.Conn) {
	_ = conn.SetReadDeadline(time.Now().Add(90 * time.Second))
	conn.SetPongHandler(func(string) error {
		_ = conn.SetReadDeadline(time.Now().Add(90 * time.Second))
		return nil
	})

	for {
		_, raw, err := conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				utils.Warn().Err(err).Str("user_id", userID).Msg("[WS] Read error")
			}
			return
		}

		// Perpanjang deadline setiap ada pesan masuk (termasuk PING heartbeat)
		_ = conn.SetReadDeadline(time.Now().Add(90 * time.Second))

		var msg hub.Message
		if err := json.Unmarshal(raw, &msg); err != nil {
			utils.Warn().Err(err).Str("user_id", userID).Msg("[WS] Invalid JSON")
			continue
		}

		// Skip PING heartbeat events - hanya untuk keep-alive, tidak perlu diproses
		if msg.Event == "PING" {
			continue
		}

		h.handleEvent(userID, msg)
	}
}

// handleEvent dispatches WS events to the appropriate handler.
func (h *Handler) handleEvent(userID string, msg hub.Message) {
	switch msg.Event {
	case "TRIGGER_SOS":
		h.onTriggerSOS(userID, msg.Payload)
	case "CANCEL_SOS":
		h.onCancelSOS(userID, msg.Payload)
	case "ACCEPT_RESCUE":
		h.onAcceptRescue(userID, msg.Payload)
	case "UPDATE_LOCATION":
		h.onUpdateLocation(userID, msg.Payload)
	default:
		utils.Warn().Str("event", msg.Event).Str("user_id", userID).Msg("[WS] Unknown event")
	}
}

// ─── Event Handlers ────────────────────────────────────────────────────────────

func (h *Handler) onUpdateLocation(userID string, payload interface{}) {
	p := toMap(payload)
	lat, _ := p["latitude"].(float64)
	lng, _ := p["longitude"].(float64)

	// Cek role user untuk menentukan update kemana
	var role string
	h.db.Raw("SELECT role FROM users WHERE id = ?", userID).Scan(&role)

	switch role {
	case "masyarakat":
		// Cari SOS aktif milik user ini
		inc, _ := h.incRepo.FindActiveByReporter(userID)
		if inc != nil {
			// Update di DB
			_ = h.incRepo.UpdateLocation(inc.ID, lat, lng)

			msg := hub.Message{
				Event: "REPORTER_LOCATION_UPDATE",
				Payload: map[string]interface{}{
					"sos_id":    inc.ID,
					"user_id":   userID,
					"latitude":  lat,
					"longitude": lng,
				},
			}

			// Broadcast ke relawan yang sedang handle
			responses, _ := h.incRepo.FindResponsesByIncident(inc.ID)
			for _, r := range responses {
				if r.Status == "on_scene" || r.Status == "en_route" {
					_ = h.hub.SendToUser(r.ResponderID, msg)
				}
			}

			// Broadcast ke Agency & Admin
			h.hub.BroadcastToRole("agency", msg)
			h.hub.BroadcastToRole("admin", msg)
			h.hub.BroadcastToRole("superadmin", msg)
		}
	case "relawan":
		// Cari misi aktif milik relawan ini
		resp, _ := h.incRepo.GetActiveResponse(userID)
		if resp != nil {
			// Update di DB
			_ = h.incRepo.UpdateResponseLocation(resp.IncidentID, userID, lat, lng, nil)

			msg := hub.Message{
				Event: "VOLUNTEER_LOCATION_UPDATE",
				Payload: map[string]interface{}{
					"incident_id": resp.IncidentID,
					"user_id":     userID,
					"latitude":    lat,
					"longitude":   lng,
				},
			}

			// Broadcast ke korban (reporter)
			inc, _ := h.incRepo.FindByID(resp.IncidentID)
			if inc != nil {
				_ = h.hub.SendToUser(inc.ReporterID, msg)
			}

			// Broadcast ke Agency & Admin
			h.hub.BroadcastToRole("agency", msg)
			h.hub.BroadcastToRole("admin", msg)
			h.hub.BroadcastToRole("superadmin", msg)
		}
	}
}

func (h *Handler) onTriggerSOS(userID string, payload interface{}) {
	p := toMap(payload)
	lat, _ := p["latitude"].(float64)
	lng, _ := p["longitude"].(float64)

	ctx := context.Background()

	// 1. Insert incident with status = grace_period
	inc := &incident.Incident{
		ReporterID:   userID,
		IncidentType: "unknown",
		Latitude:     lat,
		Longitude:    lng,
		Status:       "grace_period",
	}
	if err := h.incRepo.CreateIncident(inc); err != nil {
		utils.Error().Err(err).Str("user_id", userID).Msg("[WS] Failed to create incident")
		return
	}

	// 2. Set grace period key in Redis (expires in 10s)
	graceKey := fmt.Sprintf(incidentGraceKey, inc.ID)
	h.rdb.Set(ctx, graceKey, "active", gracePeriod)

	// 3. Store location for later broadcasting
	locKey := fmt.Sprintf(incidentLocKey, inc.ID)
	h.rdb.HSet(ctx, locKey, "lat", lat, "lng", lng, "reporter_id", userID)
	h.rdb.Expire(ctx, locKey, 2*time.Minute)

	// 4. ACK to the victim
	_ = h.hub.SendToUser(userID, hub.Message{
		Event: "SOS_ACKNOWLEDGED",
		Payload: map[string]interface{}{
			"sos_id":       inc.ID,
			"grace_period": int(gracePeriod.Seconds()),
			"message":      "SOS diterima. Batalkan dalam 10 detik jika ini bukan darurat.",
		},
	})

	utils.Info().
		Str("user_id", userID).
		Str("incident_id", inc.ID).
		Int("grace_seconds", int(gracePeriod.Seconds())).
		Msg("[WS] SOS triggered")
}

func (h *Handler) onCancelSOS(userID string, payload interface{}) {
	p := toMap(payload)
	sosID, _ := p["sos_id"].(string)

	ctx := context.Background()

	// 1. Delete grace period key
	graceKey := fmt.Sprintf(incidentGraceKey, sosID)
	h.rdb.Del(ctx, graceKey)

	// 2. Update incident status to false_alarm
	_ = h.incRepo.UpdateStatus(sosID, "false_alarm")

	_ = h.hub.SendToUser(userID, hub.Message{
		Event:   "SOS_CANCELLED",
		Payload: map[string]string{"message": "SOS dibatalkan"},
	})

	utils.Info().Str("sos_id", sosID).Str("user_id", userID).Msg("[WS] SOS canceled")
}

func (h *Handler) onAcceptRescue(responderID string, payload interface{}) {
	p := toMap(payload)
	sosID, _ := p["sos_id"].(string)

	// 1. Create incident_response record
	resp := &incident.IncidentResponse{
		IncidentID:  sosID,
		ResponderID: responderID,
		Status:      "en_route",
	}
	if err := h.incRepo.CreateResponse(resp); err != nil {
		utils.Error().Err(err).Str("sos_id", sosID).Str("responder_id", responderID).Msg("[WS] Failed to create response")
		return
	}

	// 2. Get responder name from DB
	var responderName string
	h.db.Raw("SELECT full_name FROM users WHERE id = ?", responderID).Scan(&responderName)

	// 3. Get reporter ID from incident
	inc, err := h.incRepo.FindByID(sosID)
	if err != nil {
		utils.Error().Err(err).Str("sos_id", sosID).Msg("[WS] Incident not found")
		return
	}

	// 4. Notify the victim
	_ = h.hub.SendToUser(inc.ReporterID, hub.Message{
		Event: "RESCUE_ACCEPTED",
		Payload: map[string]interface{}{
			"responder_id":   responderID,
			"responder_name": responderName,
			"status":         "en_route",
			"message":        fmt.Sprintf("Relawan %s sedang menuju lokasi kamu", responderName),
		},
	})

	utils.Info().
		Str("sos_id", sosID).
		Str("responder_id", responderID).
		Str("responder_name", responderName).
		Msg("[WS] Rescue accepted")
}

// ─── Redis Expired Key Subscriber ─────────────────────────────────────────────

// startExpiredKeySubscriber listens for Redis expired key events and triggers
// SOS broadcasting when a grace period key expires.
func (h *Handler) startExpiredKeySubscriber() {
	ctx := context.Background()
	pubsub := h.rdb.PSubscribe(ctx, "__keyevent@0__:expired")

	go func() {
		defer func() { _ = pubsub.Close() }()
		utils.Info().Msg("[WS] Redis expired-key subscriber started")
		ch := pubsub.Channel()

		for msg := range ch {
			key := msg.Payload
			// Only react to grace period keys: "incident:{uuid}:grace"
			if !strings.Contains(key, ":grace") {
				continue
			}

			// Extract UUID between "incident:" and ":grace"
			key = strings.TrimPrefix(key, "incident:")
			incidentID := strings.TrimSuffix(key, ":grace")
			if incidentID == "" {
				continue
			}

			utils.Info().Str("incident_id", incidentID).Msg("[WS] Grace period expired → broadcasting SOS")
			go h.broadcastSOS(incidentID)
		}
	}()
}

// broadcastSOS is called when the grace period expires.
// It updates the incident status and sends INCOMING_EMERGENCY to nearby volunteers.
func (h *Handler) broadcastSOS(incidentID string) {
	ctx, canceled := context.WithTimeout(context.Background(), 10*time.Second)
	defer canceled()

	// 1. Update incident status to broadcasting
	_ = h.incRepo.UpdateStatus(incidentID, "broadcasting")

	// 2. Retrieve victim location from Redis
	locKey := fmt.Sprintf(incidentLocKey, incidentID)
	vals, err := h.rdb.HGetAll(ctx, locKey).Result()
	if err != nil || len(vals) == 0 {
		utils.Error().Err(err).Str("incident_id", incidentID).Msg("[WS] Location not found for incident")
		return
	}

	var lat, lng float64
	_, _ = fmt.Sscanf(vals["lat"], "%f", &lat)
	_, _ = fmt.Sscanf(vals["lng"], "%f", &lng)
	reporterID := vals["reporter_id"]

	// 3. GEORADIUS - find volunteers within 5 km
	volunteers, err := h.rdb.GeoRadius(ctx, relawanGeoKey, lng, lat, &redis.GeoRadiusQuery{ //nolint:staticcheck
		Radius:   5,
		Unit:     "km",
		WithDist: true,
		Sort:     "ASC",
	}).Result()
	if err != nil {
		utils.Error().Err(err).Str("incident_id", incidentID).Msg("[WS] GeoRadius error")
		return
	}

	msg := hub.Message{
		Event: "INCOMING_EMERGENCY",
		Payload: map[string]interface{}{
			"incident_id": incidentID,
			"reporter_id": reporterID,
			"latitude":    lat,
			"longitude":   lng,
		},
	}

	sent := 0
	for _, v := range volunteers {
		if v.Name == reporterID {
			continue
		}
		if err := h.hub.SendToUser(v.Name, msg); err == nil {
			sent++
		}
	}

	// ─── Broadcast ke Agency/Admin yang sedang online ───────────────────────────
	// Ganti query city_code (kolom tidak ada) dengan pengecekan role pada user online
	for _, userID := range h.hub.OnlineUsers() {
		if userID == reporterID {
			continue
		}
		// Cek role dari Redis cache dulu, fallback ke DB
		var role string
		roleKey := fmt.Sprintf("user:role:%s", userID)
		role, _ = h.rdb.Get(ctx, roleKey).Result()
		if role == "" {
			h.db.Raw("SELECT role FROM users WHERE id = ?", userID).Scan(&role)
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

	utils.Info().Str("incident_id", incidentID).Int("sent_count", sent).Msg("[WS] SOS broadcast completed")
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

// toMap safely converts interface{} payload (from JSON unmarshal) to map[string]interface{}.
func toMap(v interface{}) map[string]interface{} {
	if m, ok := v.(map[string]interface{}); ok {
		return m
	}
	return map[string]interface{}{}
}

// BroadcastIncidentUpdated mengirim event INCIDENT_UPDATED ke semua koneksi
// console (agency, admin, superadmin) yang sedang online.
// Dipanggil setelah setiap aksi yang mengubah status insiden:
// AcceptSOS, AgencyHandle, AgencyReview, AgencyResolve, VolunteerComplete.
func (h *Handler) BroadcastIncidentUpdated(incidentID, action string) {
	msg := hub.Message{
		Event: "INCIDENT_UPDATED",
		Payload: map[string]interface{}{
			"incident_id": incidentID,
			"action":      action, // e.g. "agency_handle", "resolved", "volunteer_complete"
		},
	}

	sentAgency := h.hub.BroadcastToRole("agency", msg)
	sentAdmin := h.hub.BroadcastToRole("admin", msg)
	sentSuperadmin := h.hub.BroadcastToRole("superadmin", msg)

	utils.Info().
		Str("incident_id", incidentID).
		Str("action", action).
		Int("sent_agency", sentAgency).
		Int("sent_admin", sentAdmin).
		Int("sent_superadmin", sentSuperadmin).
		Msg("[WS] INCIDENT_UPDATED broadcasted")
}

