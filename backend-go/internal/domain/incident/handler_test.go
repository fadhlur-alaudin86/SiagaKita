package incident

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"strings"
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
	incidents.Post("/:id/personnel-status", func(c *fiber.Ctx) error {
		c.Locals("userID", "test-personnel-id")
		return h.PersonnelUpdateStatus(c)
	})
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

func TestIsIncidentTerminal(t *testing.T) {
	tests := []struct {
		status   string
		expected bool
	}{
		{StatusResolved, true},
		{StatusCanceled, true},
		{StatusFalseAlarm, true},
		{StatusHandled, false},
		{StatusHandling, false},
		{StatusGracePeriod, false},
		{"unknown_status", false},
		{"", false},
	}

	for _, tc := range tests {
		t.Run(tc.status, func(t *testing.T) {
			got := isIncidentTerminal(tc.status)
			if got != tc.expected {
				t.Errorf("isIncidentTerminal(%q) = %v, expected %v", tc.status, got, tc.expected)
			}
		})
	}
}

func TestCreateReport_Validation(t *testing.T) {
	h := NewHandler(&Service{}, &config.Config{}, hub.New(), nil)
	app := fiber.New()
	app.Use(func(c *fiber.Ctx) error {
		c.Locals("userID", "test-reporter-123")
		return c.Next()
	})
	app.Post("/api/v1/reports", h.CreateReport)

	t.Run("BadRequest_MissingIncidentType", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/api/v1/reports", strings.NewReader("latitude=-6.2&longitude=106.8"))
		req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if resp.StatusCode != http.StatusBadRequest {
			t.Errorf("expected 400, got %d", resp.StatusCode)
		}
	})

	t.Run("BadRequest_ZeroCoordinates", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/api/v1/reports", strings.NewReader("incident_type=medical&latitude=0&longitude=0"))
		req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if resp.StatusCode != http.StatusBadRequest {
			t.Errorf("expected 400, got %d", resp.StatusCode)
		}
	})
}

func TestPersonnelUpdateStatus_Validation(t *testing.T) {
	rdb := redis.NewClient(&redis.Options{Addr: "localhost:9999"})
	wsHub := hub.New()
	cfg := &config.Config{}
	svc := &Service{repo: nil, rdb: rdb}
	h := NewHandler(svc, cfg, wsHub, rdb)
	app := setupTestApp(h)

	t.Run("BadRequest_InvalidJSON", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/api/v1/incidents/inc-123/personnel-status", bytes.NewReader([]byte("{invalid-json")))
		req.Header.Set("Content-Type", "application/json")
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if resp.StatusCode != http.StatusBadRequest {
			t.Errorf("expected 400, got %d", resp.StatusCode)
		}
	})

	t.Run("BadRequest_EmptyStatus", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/api/v1/incidents/inc-123/personnel-status", bytes.NewReader([]byte(`{"status": ""}`)))
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
