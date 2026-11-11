package incident

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"siagakita-backend/internal/config"
	"siagakita-backend/internal/domain/admin"
	"siagakita-backend/internal/domain/agency"
	"siagakita-backend/internal/domain/user"
	"siagakita-backend/internal/hub"
	"siagakita-backend/internal/utils"

	"github.com/gofiber/fiber/v2"
	"github.com/redis/go-redis/v9"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
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

func TestCancelSOS_Handler(t *testing.T) {
	db := getTestDB()
	if db == nil {
		t.Skip("PostgreSQL test database unavailable, skipping integration test")
	}

	var testUserID string
	if err := db.Raw("SELECT id FROM users WHERE role = 'civilian' LIMIT 1").Scan(&testUserID).Error; err != nil || testUserID == "" {
		t.Skip("No civilian user found in test database, skipping test")
	}

	newIncident := func(status string) *Incident {
		inc := &Incident{
			ReporterID:   testUserID,
			Latitude:     -6.2088,
			Longitude:    106.8456,
			IncidentType: "medical",
			Status:       status,
			CreatedAt:    time.Now(),
			UpdatedAt:    time.Now(),
		}
		if err := db.Create(inc).Error; err != nil {
			t.Fatalf("failed to create incident: %v", err)
		}
		return inc
	}

	cases := []struct {
		name       string
		setup      func() string
		userID     string
		wantStatus int
		wantCode   string
	}{
		{
			name:       "success",
			setup:      func() string { return newIncident(StatusBroadcasting).ID },
			userID:     testUserID,
			wantStatus: http.StatusOK,
			wantCode:   "",
		},
		{
			name:       "unauthorized",
			setup:      func() string { return newIncident(StatusBroadcasting).ID },
			userID:     "00000000-0000-0000-0000-000000000000",
			wantStatus: http.StatusForbidden,
			wantCode:   "ERR_FORBIDDEN",
		},
		{
			name:       "not_found",
			setup:      func() string { return "00000000-0000-0000-0000-000000000000" },
			userID:     testUserID,
			wantStatus: http.StatusInternalServerError,
			wantCode:   "ERR_INTERNAL",
		},
	}

	for _, tt := range cases {
		t.Run(tt.name, func(t *testing.T) {
			incidentID := tt.setup()
			defer db.Exec("DELETE FROM incidents WHERE id = ?", incidentID)

			repo := NewRepository(db)
			svc := NewService(repo, nil)
			h := NewHandler(svc, &config.Config{}, hub.New(), nil)

			app := fiber.New()
			app.Post("/api/v1/incidents/:id/canceled", func(c *fiber.Ctx) error {
				c.Locals("userID", tt.userID)
				return h.CancelSOS(c)
			})

			req := httptest.NewRequest(http.MethodPost, "/api/v1/incidents/"+incidentID+"/canceled", nil)
			resp, err := app.Test(req)
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if resp.StatusCode != tt.wantStatus {
				t.Errorf("expected %d, got %d", tt.wantStatus, resp.StatusCode)
			}
			body, _ := io.ReadAll(resp.Body)
			var res utils.APIResponse
			_ = json.Unmarshal(body, &res)
			if res.Code != tt.wantCode {
				t.Errorf("expected code %q, got %q", tt.wantCode, res.Code)
			}
		})
	}
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

// TestUnauthenticatedHandlersReturn401 verifies that every handler which reads
// auth locals returns HTTP 401 with a Rule B machine-readable code
// (ERR_UNAUTHORIZED) instead of panicking into a 500 when the auth middleware
// did not populate locals. Each affected route is registered WITHOUT auth
// middleware and WITHOUT setting userID locals, so the comma-ok guard is the
// only thing standing between the request and a nil-map panic.
func TestUnauthenticatedHandlersReturn401(t *testing.T) {
	incH := NewHandler(&Service{}, &config.Config{}, hub.New(), nil)
	agH := agency.NewHandler(&agency.Service{})
	adH := admin.NewHandler(&admin.Service{}, &config.Config{})
	usH := user.NewHandler(&user.Service{})

	tests := []struct {
		name   string
		method string
		path   string
		handle fiber.Handler
	}{
		// Incident (reporter)
		{"TriggerSOS", fiber.MethodPost, "/api/v1/incidents/trigger", incH.TriggerSOS},
		{"UpdateType", fiber.MethodPatch, "/api/v1/incidents/inc-1/type", incH.UpdateType},
		{"Broadcast", fiber.MethodPost, "/api/v1/incidents/inc-1/broadcast", incH.Broadcast},
		{"CancelSOS", fiber.MethodPost, "/api/v1/incidents/inc-1/canceled", incH.CancelSOS},
		{"UploadEvidence", fiber.MethodPost, "/api/v1/incidents/inc-1/evidence", incH.UploadEvidence},
		{"GetActive", fiber.MethodGet, "/api/v1/incidents/active", incH.GetActive},
		{"GetHistory", fiber.MethodGet, "/api/v1/incidents/reporter-history", incH.GetHistory},
		{"MarkFalseAlarm", fiber.MethodPost, "/api/v1/incidents/inc-1/mark-false-alarm", incH.MarkFalseAlarm},
		{"Resolve", fiber.MethodPost, "/api/v1/incidents/inc-1/resolve", incH.Resolve},
		{"CreateReport", fiber.MethodPost, "/api/v1/reports", incH.CreateReport},
		{"CancelReport", fiber.MethodPost, "/api/v1/reports/inc-1/canceled", incH.CancelReport},
		{"GetMyReports", fiber.MethodGet, "/api/v1/reports/my", incH.GetMyReports},
		// Incident (volunteer)
		{"GetNearby", fiber.MethodGet, "/api/v1/incidents/nearby", incH.GetNearby},
		{"AcceptSOS", fiber.MethodPost, "/api/v1/incidents/inc-1/accept", incH.AcceptSOS},
		{"AgencyHandleSOS", fiber.MethodPost, "/api/v1/incidents/inc-1/agency-handle", incH.AgencyHandleSOS},
		{"VolunteerCompleteSOS", fiber.MethodPost, "/api/v1/incidents/inc-1/volunteer-complete", incH.VolunteerCompleteSOS},
		{"GetMissionHistory", fiber.MethodGet, "/api/v1/incidents/my-history", incH.GetMissionHistory},
		{"GetVolunteerBadges", fiber.MethodGet, "/api/v1/volunteer/badges", incH.GetVolunteerBadges},
		{"GetMyActiveResponse", fiber.MethodGet, "/api/v1/incidents/my-active-response", incH.GetMyActiveResponse},
		{"UpdateResponseLocation", fiber.MethodPut, "/api/v1/incidents/inc-1/response-location", incH.UpdateResponseLocation},
		// Incident (personnel)
		{"PersonnelUpdateStatus", fiber.MethodPost, "/api/v1/incidents/inc-1/personnel-status", incH.PersonnelUpdateStatus},
		{"GetPersonnelActiveMission", fiber.MethodGet, "/api/v1/incidents/responder/active-mission", incH.GetPersonnelActiveMission},
		// Agency
		{"AgencyCreatePersonnel", fiber.MethodPost, "/api/v1/agencies/personnels", agH.CreatePersonnel},
		{"AgencyGetMyProfile", fiber.MethodGet, "/api/v1/agencies/me", agH.GetMyProfile},
		// Admin
		{"AdminCreateAdmin", fiber.MethodPost, "/api/v1/admin/admins", adH.CreateAdmin},
		// User
		{"UserSaveBiodata", fiber.MethodPost, "/api/v1/users/biodata", usH.SaveBiodata},
		{"UserGetProfile", fiber.MethodGet, "/api/v1/users/profile", usH.GetProfile},
		{"UserUpdateProfile", fiber.MethodPut, "/api/v1/users/profile", usH.UpdateProfile},
		{"UserRequestPhoneVerification", fiber.MethodPost, "/api/v1/users/phone/request-otp", usH.RequestPhoneVerification},
		{"UserConfirmPhoneOTP", fiber.MethodPost, "/api/v1/users/phone/verify-otp", usH.ConfirmPhoneOTP},
		{"UserSubmitKYC", fiber.MethodPost, "/api/v1/users/kyc", usH.SubmitKYC},
		{"UserGetKYCStatus", fiber.MethodGet, "/api/v1/users/kyc/status", usH.GetKYCStatus},
		{"UserSubmitVolunteerRegistration", fiber.MethodPost, "/api/v1/users/volunteer/register", usH.SubmitVolunteerRegistration},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			app := fiber.New()
			app.Add(tt.method, tt.path, tt.handle)

			req := httptest.NewRequest(tt.method, tt.path, nil)
			resp, err := app.Test(req)
			require.NoError(t, err)
			defer resp.Body.Close()

			require.Equal(t, fiber.StatusUnauthorized, resp.StatusCode, "handler must not panic into 500")

			var envelope struct {
				Success bool   `json:"success"`
				Code    string `json:"code"`
				Message string `json:"message"`
			}
			require.NoError(t, json.NewDecoder(resp.Body).Decode(&envelope))
			assert.False(t, envelope.Success)
			assert.Equal(t, "ERR_UNAUTHORIZED", envelope.Code, "Rule B machine-readable code")
			assert.NotEmpty(t, envelope.Message)
		})
	}
}
