package telemetry

import (
	"context"
	"fmt"
	"strings"
	"time"

	"siagakita-backend/internal/config"
	"siagakita-backend/internal/hub"
	"siagakita-backend/internal/utils"

	"github.com/gofiber/fiber/v2"
	"github.com/redis/go-redis/v9"
)

const relawanGeoKey = "relawan:locations"

// Handler holds HTTP handlers for the telemetry domain.
type Handler struct {
	rdb *redis.Client
	h   *hub.Hub
	cfg *config.Config
}

// NewHandler creates a new telemetry Handler.
func NewHandler(rdb *redis.Client, h *hub.Hub, cfg *config.Config) *Handler {
	return &Handler{rdb: rdb, h: h, cfg: cfg}
}

// UpdateLocation handles PUT /api/v1/telemetry/location  [Auth required]
// Stores the volunteer's GPS position in Redis GEO (no PostgreSQL write).
func (h *Handler) UpdateLocation(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)

	var body struct {
		Latitude  float64 `json:"latitude"`
		Longitude float64 `json:"longitude"`
	}
	if err := c.BodyParser(&body); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}

	ctx, canceled := context.WithTimeout(context.Background(), 3*time.Second)
	defer canceled()

	if err := h.rdb.GeoAdd(ctx, relawanGeoKey, &redis.GeoLocation{
		Name:      userID,
		Latitude:  body.Latitude,
		Longitude: body.Longitude,
	}).Err(); err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Gagal menyimpan lokasi")
	}

	// Broadcast lokasi terbaru ke admin & agency yang sedang online
	h.h.BroadcastToRole("admin", hub.Message{
		Event: "VOLUNTEER_LOCATION_UPDATE",
		Payload: map[string]interface{}{
			"user_id":   userID,
			"latitude":  body.Latitude,
			"longitude": body.Longitude,
			"timestamp": time.Now().Unix(),
		},
	})
	h.h.BroadcastToRole("agency", hub.Message{
		Event: "VOLUNTEER_LOCATION_UPDATE",
		Payload: map[string]interface{}{
			"user_id":   userID,
			"latitude":  body.Latitude,
			"longitude": body.Longitude,
			"timestamp": time.Now().Unix(),
		},
	})
	h.h.BroadcastToRole("superadmin", hub.Message{
		Event: "VOLUNTEER_LOCATION_UPDATE",
		Payload: map[string]interface{}{
			"user_id":   userID,
			"latitude":  body.Latitude,
			"longitude": body.Longitude,
			"timestamp": time.Now().Unix(),
		},
	})

	return utils.SuccessResponse(c, fiber.Map{"message": "Lokasi diperbarui"})
}

// GetOnlineStatus handles POST /api/v1/telemetry/online-status [ConsoleOnly]
// Accepts a list of user IDs and returns a map of {userID: bool} based on Redis TTL.
func (h *Handler) GetOnlineStatus(c *fiber.Ctx) error {
	var body struct {
		UserIDs []string `json:"user_ids"`
	}
	if err := c.BodyParser(&body); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}

	ctx, canceled := context.WithTimeout(context.Background(), 3*time.Second)
	defer canceled()

	statusMap := make(map[string]bool)
	if len(body.UserIDs) == 0 {
		return utils.SuccessResponse(c, statusMap)
	}

	// Use Redis Pipeline for efficient bulk get
	pipe := h.rdb.Pipeline()
	cmds := make(map[string]*redis.StringCmd)
	for _, id := range body.UserIDs {
		cmds[id] = pipe.Get(ctx, "user:online:"+id)
	}

	_, _ = pipe.Exec(ctx) // Ignore error because key not found returns redis.Nil

	for id, cmd := range cmds {
		val, err := cmd.Result()
		statusMap[id] = (err == nil && val == "1")
	}

	return utils.SuccessResponse(c, statusMap)
}

// SMSFallback handles POST /api/v1/incidents/sms-fallback  [API Key required]
// Parses a raw SMS string, skips grace period, and immediately broadcasts
// INCOMING_EMERGENCY to nearby online volunteers via the Hub.
func (h *Handler) SMSFallback(c *fiber.Ctx) error {
	var body struct {
		RawSMS string `json:"raw_sms"`
	}
	if err := c.BodyParser(&body); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}

	// Expected format: "SOS|<userID>|<latitude>|<longitude>"
	parts := strings.Split(body.RawSMS, "|")
	if len(parts) != 4 || parts[0] != "SOS" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Format SMS tidak valid. Gunakan: SOS|<userID>|<lat>|<lng>")
	}

	userID := parts[1]
	latStr := parts[2]
	lngStr := parts[3]

	var lat, lng float64
	if _, err := fmt.Sscanf(latStr, "%f", &lat); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Latitude tidak valid")
	}
	if _, err := fmt.Sscanf(lngStr, "%f", &lng); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Longitude tidak valid")
	}

	// Skip grace period — broadcast immediately to nearby volunteers
	go broadcastEmergency(h.rdb, h.h, "sms-fallback", userID, lat, lng)

	return utils.SuccessResponse(c, fiber.Map{
		"message": "SMS fallback diterima, broadcasting ke relawan terdekat",
	})
}

// broadcastEmergency finds nearby volunteers via Redis GEORADIUS and sends
// INCOMING_EMERGENCY to all online volunteers within 5 km.
func broadcastEmergency(rdb *redis.Client, h *hub.Hub, incidentID interface{}, reporterID string, lat, lng float64) {
	ctx, canceled := context.WithTimeout(context.Background(), 5*time.Second)
	defer canceled()

	// Find volunteers within 5 km
	locations, err := rdb.GeoRadius(ctx, relawanGeoKey, lng, lat, &redis.GeoRadiusQuery{ //nolint:staticcheck
		Radius:    5,
		Unit:      "km",
		WithCoord: true,
		WithDist:  true,
		Sort:      "ASC",
	}).Result()
	if err != nil {
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

	for _, loc := range locations {
		volunteerID := loc.Name
		if volunteerID == reporterID {
			continue // skip the reporter themselves
		}
		_ = h.SendToUser(volunteerID, msg)
	}
}

// BroadcastEmergency is exported so the WebSocket handler can call it too.
var BroadcastEmergency = broadcastEmergency
