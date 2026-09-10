package telemetry

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"siagakita-backend/internal/config"
	"siagakita-backend/internal/hub"

	"github.com/gofiber/fiber/v2"
	"github.com/redis/go-redis/v9"
)

func setupTestApp(h *Handler) *fiber.App {
	app := fiber.New()
	tel := app.Group("/api/v1/telemetry")
	tel.Get("/nearby-volunteers", h.GetNearbyVolunteers)
	return app
}

func TestGetNearbyVolunteers_Validation(t *testing.T) {
	// Create handler with dummy redis client since validation occurs before DB calls
	rdb := redis.NewClient(&redis.Options{Addr: "localhost:9999"})
	wsHub := hub.New()
	cfg := &config.Config{}
	h := NewHandler(rdb, wsHub, cfg)
	app := setupTestApp(h)

	t.Run("BadRequest_MissingLatLng", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/telemetry/nearby-volunteers", nil)
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if resp.StatusCode != http.StatusBadRequest {
			t.Errorf("expected status 400, got %d", resp.StatusCode)
		}
	})

	t.Run("BadRequest_MissingLng", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/telemetry/nearby-volunteers?lat=-6.2088", nil)
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if resp.StatusCode != http.StatusBadRequest {
			t.Errorf("expected status 400, got %d", resp.StatusCode)
		}
	})

	t.Run("BadRequest_InvalidLat", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/telemetry/nearby-volunteers?lat=not-a-number&lng=106.8456", nil)
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if resp.StatusCode != http.StatusBadRequest {
			t.Errorf("expected status 400, got %d", resp.StatusCode)
		}
	})

	t.Run("BadRequest_InvalidLng", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/telemetry/nearby-volunteers?lat=-6.2088&lng=not-a-number", nil)
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if resp.StatusCode != http.StatusBadRequest {
			t.Errorf("expected status 400, got %d", resp.StatusCode)
		}
	})
}
