package incident

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

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

func TestUploadEvidence_NonExistentIncident_Returns404(t *testing.T) {
	db := getTestDB()
	if db == nil {
		t.Skip("PostgreSQL test database unavailable, skipping integration test")
	}

	repo := NewRepository(db)
	svc := NewService(repo, nil)
	cfg := &config.Config{
		UploadDir: t.TempDir(),
	}
	wsHub := hub.New()
	h := NewHandler(svc, cfg, wsHub, nil)

	app := fiber.New()
	app.Post("/api/v1/incidents/:id/evidence", func(c *fiber.Ctx) error {
		c.Locals("userID", "any-reporter-id")
		return h.UploadEvidence(c)
	})

	nonExistentID := "00000000-0000-0000-0000-000000000000"
	req := httptest.NewRequest(http.MethodPost, "/api/v1/incidents/"+nonExistentID+"/evidence", nil)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("expected 404, got %d", resp.StatusCode)
	}

	// Verify no directory or files were created in UploadDir
	entries, err := os.ReadDir(cfg.UploadDir)
	if err != nil {
		t.Fatalf("failed to read upload dir: %v", err)
	}
	if len(entries) != 0 {
		t.Errorf("expected upload dir to be empty, found %d entries", len(entries))
	}
}

func TestUploadEvidence_UnauthorizedReporter_Returns403(t *testing.T) {
	db := getTestDB()
	if db == nil {
		t.Skip("PostgreSQL test database unavailable, skipping integration test")
	}

	repo := NewRepository(db)
	svc := NewService(repo, nil)
	cfg := &config.Config{
		UploadDir: t.TempDir(),
	}
	wsHub := hub.New()
	h := NewHandler(svc, cfg, wsHub, nil)

	var testUserID string
	if err := db.Raw("SELECT id FROM users WHERE role = 'civilian' LIMIT 1").Scan(&testUserID).Error; err != nil || testUserID == "" {
		t.Skip("No civilian user found in test database, skipping test")
	}

	inc := &Incident{
		ReporterID:   testUserID,
		Latitude:     -6.2088,
		Longitude:    106.8456,
		IncidentType: "medical",
		Status:       StatusBroadcasting,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}
	if err := repo.CreateIncident(inc); err != nil {
		t.Fatalf("failed to create incident: %v", err)
	}
	defer db.Exec("DELETE FROM incidents WHERE id = ?", inc.ID)

	app := fiber.New()
	app.Post("/api/v1/incidents/:id/evidence", func(c *fiber.Ctx) error {
		c.Locals("userID", "different-unauthorized-user-id")
		return h.UploadEvidence(c)
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/incidents/"+inc.ID+"/evidence", nil)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.StatusCode != http.StatusForbidden {
		t.Errorf("expected 403, got %d", resp.StatusCode)
	}

	// Verify no directory or files were created in UploadDir
	entries, err := os.ReadDir(cfg.UploadDir)
	if err != nil {
		t.Fatalf("failed to read upload dir: %v", err)
	}
	if len(entries) != 0 {
		t.Errorf("expected upload dir to be empty, found %d entries", len(entries))
	}
}
