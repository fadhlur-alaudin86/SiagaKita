package ws

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
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
		log.Printf("[WS] Upgrade error: %v", err)
		return
	}

	userID := claims.UserID
	h.hub.Register(userID, conn)
	defer h.hub.Unregister(userID)

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
				log.Printf("[WS] Read error for user %s: %v", userID, err)
			}
			return
		}

		// Perpanjang deadline setiap ada pesan masuk (termasuk PING heartbeat)
		_ = conn.SetReadDeadline(time.Now().Add(90 * time.Second))

		var msg hub.Message
		if err := json.Unmarshal(raw, &msg); err != nil {
			log.Printf("[WS] Invalid JSON from user %s: %v", userID, err)
			continue
		}

		// Skip PING heartbeat events — hanya untuk keep-alive, tidak perlu diproses
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
	default:
		log.Printf("[WS] Unknown event %q from user %s", msg.Event, userID)
	}
}

// ─── Event Handlers ────────────────────────────────────────────────────────────

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
		log.Printf("[WS] Failed to create incident for user %s: %v", userID, err)
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

	log.Printf("[WS] SOS triggered by user %s → incident %s (grace %ds)", userID, inc.ID, int(gracePeriod.Seconds()))
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

	log.Printf("[WS] SOS %s cancelled by user %s", sosID, userID)
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
		log.Printf("[WS] Failed to create response for incident %s: %v", sosID, err)
		return
	}

	// 2. Get responder name from DB
	var responderName string
	h.db.Raw("SELECT full_name FROM users WHERE id = ?", responderID).Scan(&responderName)

	// 3. Get reporter ID from incident
	inc, err := h.incRepo.FindByID(sosID)
	if err != nil {
		log.Printf("[WS] Incident %s not found: %v", sosID, err)
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

	log.Printf("[WS] Rescue accepted: incident %s ← relawan %s (%s)", sosID, responderID, responderName)
}

// ─── Redis Expired Key Subscriber ─────────────────────────────────────────────

// startExpiredKeySubscriber listens for Redis expired key events and triggers
// SOS broadcasting when a grace period key expires.
func (h *Handler) startExpiredKeySubscriber() {
	ctx := context.Background()
	pubsub := h.rdb.PSubscribe(ctx, "__keyevent@0__:expired")

	go func() {
		defer func() { _ = pubsub.Close() }()
		log.Println("[WS] Redis expired-key subscriber started")
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

			log.Printf("[WS] Grace period expired for incident %s → broadcasting SOS", incidentID)
			go h.broadcastSOS(incidentID)
		}
	}()
}

// broadcastSOS is called when the grace period expires.
// It updates the incident status and sends INCOMING_EMERGENCY to nearby volunteers.
func (h *Handler) broadcastSOS(incidentID string) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// 1. Update incident status to broadcasting
	_ = h.incRepo.UpdateStatus(incidentID, "broadcasting")

	// 2. Retrieve victim location from Redis
	locKey := fmt.Sprintf(incidentLocKey, incidentID)
	vals, err := h.rdb.HGetAll(ctx, locKey).Result()
	if err != nil || len(vals) == 0 {
		log.Printf("[WS] Location not found for incident %s", incidentID)
		return
	}

	var lat, lng float64
	_, _ = fmt.Sscanf(vals["lat"], "%f", &lat)
	_, _ = fmt.Sscanf(vals["lng"], "%f", &lng)
	reporterID := vals["reporter_id"]

	// 3. GEORADIUS — find volunteers within 5 km
	volunteers, err := h.rdb.GeoRadius(ctx, relawanGeoKey, lng, lat, &redis.GeoRadiusQuery{ //nolint:staticcheck
		Radius:   5,
		Unit:     "km",
		WithDist: true,
		Sort:     "ASC",
	}).Result()
	if err != nil {
		log.Printf("[WS] GeoRadius error for incident #%s: %v", incidentID, err)
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

	// ─── Broadcast ke Agency accounts satu kota ────────────────────────────────
	// Ambil city_code dari profil pelapor
	var reporterCityCode string
	h.db.Raw(
		"SELECT city_code FROM user_profiles WHERE user_id = ?",
		reporterID,
	).Scan(&reporterCityCode)

	if reporterCityCode != "" {
		// Ambil semua account_id instansi (agency) di kota yang sama
		var agencyAccountIDs []string
		h.db.Raw(
			"SELECT account_id FROM agencies WHERE city_code = ?",
			reporterCityCode,
		).Scan(&agencyAccountIDs)

		for _, agencyID := range agencyAccountIDs {
			if err := h.hub.SendToUser(agencyID, msg); err == nil {
				sent++
			}
		}
		log.Printf("[WS] SOS #%s notified %d agencies in city %s", incidentID, len(agencyAccountIDs), reporterCityCode)
	}

	log.Printf("[WS] SOS #%s broadcast to %d/%d online volunteers", incidentID, sent, len(volunteers))
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

// toMap safely converts interface{} payload (from JSON unmarshal) to map[string]interface{}.
func toMap(v interface{}) map[string]interface{} {
	if m, ok := v.(map[string]interface{}); ok {
		return m
	}
	return map[string]interface{}{}
}
