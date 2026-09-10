package incident

import (
	"bytes"
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
	incidents := app.Group("/api/v1/incidents")
	incidents.Post("/:id/dispatch-broadcast", h.DispatchBroadcast)
	return app
}

func TestDispatchBroadcast_Validation(t *testing.T) {
	rdb := redis.NewClient(&redis.Options{Addr: "localhost:9999"})
	wsHub := hub.New()
	cfg := &config.Config{}
	svc := &Service{repo: nil, rdb: rdb}
	h := NewHandler(svc, cfg, wsHub, rdb)
	app := setupTestApp(h)

	t.Run("BadRequest_InvalidJSON", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/api/v1/incidents/inc-123/dispatch-broadcast", bytes.NewReader([]byte("{invalid-json")))
		req.Header.Set("Content-Type", "application/json")
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if resp.StatusCode != http.StatusBadRequest {
			t.Errorf("expected 400, got %d", resp.StatusCode)
		}
	})

	t.Run("BadRequest_EmptyVolunteerIDs", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/api/v1/incidents/inc-123/dispatch-broadcast", bytes.NewReader([]byte(`{"volunteer_ids": []}`)))
		req.Header.Set("Content-Type", "application/json")
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if resp.StatusCode != http.StatusBadRequest {
			t.Errorf("expected 400, got %d", resp.StatusCode)
		}
	})
}
