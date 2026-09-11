package telemetry

import (
	"context"
	"fmt"
	"strings"
	"time"

	"siagakita-backend/internal/config"
	"siagakita-backend/internal/hub"
	"siagakita-backend/internal/utils"

	"github.com/bytedance/sonic"
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
// Utilizes sync.Pool for zero-allocation JSON parsing and typed WebSocket broadcast payload.
func (h *Handler) UpdateLocation(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Unauthorized")
	}

	req := AcquireLocationUpdateRequest()
	defer ReleaseLocationUpdateRequest(req)

	if err := sonic.Unmarshal(c.Body(), req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Body request tidak valid")
	}

	if req.Latitude == 0 && req.Longitude == 0 {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Koordinat latitude dan longitude tidak valid")
	}

	ctx, canceled := context.WithTimeout(context.Background(), 3*time.Second)
	defer canceled()

	if err := h.rdb.GeoAdd(ctx, relawanGeoKey, &redis.GeoLocation{
		Name:      userID,
		Latitude:  req.Latitude,
		Longitude: req.Longitude,
	}).Err(); err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Gagal menyimpan lokasi")
	}

	// Broadcast lokasi terbaru ke admin, agency, dan superadmin yang sedang online via typed struct
	payload := LocationBroadcastPayload{
		UserID:    userID,
		Latitude:  req.Latitude,
		Longitude: req.Longitude,
		Timestamp: time.Now().Unix(),
	}
	h.h.BroadcastToRoles(hub.Message{
		Event:   EventVolunteerLocationUpdate,
		Payload: payload,
	}, "", "admin", "agency", "superadmin")

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

// NearbyVolunteerDTO represents a nearby volunteer with distance and coordinates.
type NearbyVolunteerDTO struct {
	UserID     string  `json:"user_id"`
	Latitude   float64 `json:"latitude"`
	Longitude  float64 `json:"longitude"`
	DistanceKM float64 `json:"distance_km"`
}

// GetNearbyVolunteers handles GET /api/v1/telemetry/nearby-volunteers [ConsoleOnly]
// Queries Redis GEO for volunteers within radius_km (default 15 km) from (lat, lng).
func (h *Handler) GetNearbyVolunteers(c *fiber.Ctx) error {
	latStr := c.Query("lat")
	lngStr := c.Query("lng")
	if latStr == "" || lngStr == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Parameter lat dan lng wajib diisi")
	}

	var lat, lng float64
	if _, err := fmt.Sscanf(latStr, "%f", &lat); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Parameter lat tidak valid")
	}
	if _, err := fmt.Sscanf(lngStr, "%f", &lng); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Parameter lng tidak valid")
	}

	radiusKM := 15.0
	if rStr := c.Query("radius_km"); rStr != "" {
		var r float64
		if _, err := fmt.Sscanf(rStr, "%f", &r); err == nil && r > 0 {
			radiusKM = r
		}
	}

	ctx, canceled := context.WithTimeout(context.Background(), 3*time.Second)
	defer canceled()

	locations, err := h.rdb.GeoRadius(ctx, relawanGeoKey, lng, lat, &redis.GeoRadiusQuery{ //nolint:staticcheck
		Radius:    radiusKM,
		Unit:      "km",
		WithCoord: true,
		WithDist:  true,
		Sort:      "ASC",
	}).Result()
	if err != nil && err != redis.Nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Gagal mengambil data relawan terdekat")
	}

	result := make([]NearbyVolunteerDTO, 0, len(locations))
	for _, loc := range locations {
		result = append(result, NearbyVolunteerDTO{
			UserID:     loc.Name,
			Latitude:   loc.Latitude,
			Longitude:  loc.Longitude,
			DistanceKM: loc.Dist,
		})
	}

	return utils.SuccessResponse(c, result)
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
