package admin

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"siagakita-backend/internal/config"
	"siagakita-backend/internal/middleware"
	"siagakita-backend/internal/utils"

	"github.com/gofiber/fiber/v2"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

const testJWTSecret = "test-secret-key-siagakita-minimum-32-chars-long"

func setupTestApp(h *Handler, cfg *config.Config) *fiber.App {
	app := fiber.New()
	v1 := app.Group("/api/v1")
	authMw := middleware.Auth(cfg)

	admin := v1.Group("/admin", authMw)
	admin.Get("/volunteers/pending", middleware.AdminOnly(), h.GetPendingKYC)
	admin.Post("/volunteers/:id/approve", middleware.AdminOnly(), h.ApproveKYC)
	admin.Post("/volunteers/:id/reject", middleware.AdminOnly(), h.RejectKYC)
	admin.Get("/users", middleware.AdminOnly(), h.GetUsers)
	admin.Post("/users/:id/ban", middleware.AdminOnly(), h.BanUser)
	admin.Post("/users/:id/unban", middleware.AdminOnly(), h.UnbanUser)
	admin.Delete("/users/:id/strike", middleware.AdminOnly(), h.ResetStrike)
	admin.Get("/users/:id/detail", middleware.AdminOnly(), h.GetUserDetail)

	// Master Data: Ranks
	admin.Get("/ranks", middleware.ConsoleOnly(), h.GetRanks)
	admin.Post("/ranks", middleware.AdminOnly(), h.CreateRank)
	admin.Put("/ranks/:id", middleware.AdminOnly(), h.UpdateRank)
	admin.Delete("/ranks/:id", middleware.AdminOnly(), h.DeleteRank)

	// Statistics
	admin.Get("/stats", middleware.ConsoleOnly(), h.GetStats)

	return app
}

func getOptionalTestDB() *gorm.DB {
	host := os.Getenv("DB_HOST")
	if host == "" {
		host = "localhost"
	}
	port := os.Getenv("DB_PORT")
	if port == "" {
		port = "5433"
	}
	user := os.Getenv("DB_USER")
	if user == "" {
		user = "siagakita_admin"
	}
	password := os.Getenv("DB_PASSWORD")
	if password == "" {
		password = "5566de1f136204174a3a34761d44f361e1d6299744e223609c71fe8ca8ac0978"
	}
	dbname := os.Getenv("DB_NAME")
	if dbname == "" {
		dbname = "siagakita"
	}

	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable connect_timeout=2",
		host, port, user, password, dbname)

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		return nil
	}
	sqlDB, err := db.DB()
	if err != nil || sqlDB.Ping() != nil {
		return nil
	}
	return db
}

func TestKYC_RBAC_Unauthorized(t *testing.T) {
	cfg := &config.Config{JWTSecret: testJWTSecret}
	h := NewHandler(nil, cfg)
	app := setupTestApp(h, cfg)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/admin/volunteers/pending", nil)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test failed: %v", err)
	}

	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("Expected status 401 Unauthorized, got %d", resp.StatusCode)
	}
}

func TestKYC_RBAC_Forbidden_Roles(t *testing.T) {
	cfg := &config.Config{JWTSecret: testJWTSecret}
	h := NewHandler(nil, cfg)
	app := setupTestApp(h, cfg)

	forbiddenRoles := []string{"civilian", "volunteer", "agency", "agency_personnel"}

	for _, role := range forbiddenRoles {
		t.Run("Role_"+role, func(t *testing.T) {
			token, _, err := utils.GenerateAccessToken("user-123", role, testJWTSecret, time.Hour)
			if err != nil {
				t.Fatalf("Failed to generate token: %v", err)
			}

			// 1. GET pending
			req := httptest.NewRequest(http.MethodGet, "/api/v1/admin/volunteers/pending", nil)
			req.Header.Set("Authorization", "Bearer "+token)
			resp, err := app.Test(req)
			if err != nil {
				t.Fatalf("app.Test failed: %v", err)
			}
			if resp.StatusCode != http.StatusForbidden {
				t.Errorf("[%s] Expected status 403 Forbidden for GET pending, got %d", role, resp.StatusCode)
			}

			// 2. POST approve
			reqApprove := httptest.NewRequest(http.MethodPost, "/api/v1/admin/volunteers/user-123/approve", nil)
			reqApprove.Header.Set("Authorization", "Bearer "+token)
			respApprove, err := app.Test(reqApprove)
			if err != nil {
				t.Fatalf("app.Test failed: %v", err)
			}
			if respApprove.StatusCode != http.StatusForbidden {
				t.Errorf("[%s] Expected status 403 Forbidden for POST approve, got %d", role, respApprove.StatusCode)
			}

			// 3. POST reject
			body, _ := json.Marshal(map[string]string{"reason": "Dokumen buram"})
			reqReject := httptest.NewRequest(http.MethodPost, "/api/v1/admin/volunteers/user-123/reject", bytes.NewReader(body))
			reqReject.Header.Set("Authorization", "Bearer "+token)
			reqReject.Header.Set("Content-Type", "application/json")
			respReject, err := app.Test(reqReject)
			if err != nil {
				t.Fatalf("app.Test failed: %v", err)
			}
			if respReject.StatusCode != http.StatusForbidden {
				t.Errorf("[%s] Expected status 403 Forbidden for POST reject, got %d", role, respReject.StatusCode)
			}
		})
	}
}

func TestKYC_Reject_BadRequest_InvalidJSON(t *testing.T) {
	cfg := &config.Config{JWTSecret: testJWTSecret}
	h := NewHandler(nil, cfg)
	app := setupTestApp(h, cfg)

	token, _, err := utils.GenerateAccessToken("admin-123", "admin", testJWTSecret, time.Hour)
	if err != nil {
		t.Fatalf("Failed to generate token: %v", err)
	}

	invalidBody := bytes.NewReader([]byte("{invalid-json-payload"))
	req := httptest.NewRequest(http.MethodPost, "/api/v1/admin/volunteers/target-456/reject", invalidBody)
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test failed: %v", err)
	}

	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("Expected status 400 Bad Request on invalid JSON, got %d", resp.StatusCode)
	}
}

func TestKYC_WithLiveDB(t *testing.T) {
	db := getOptionalTestDB()
	if db == nil {
		t.Skip("Database PostgreSQL tidak tersedia di localhost:5433, skipping live DB tests")
	}

	cfg := &config.Config{JWTSecret: testJWTSecret}
	svc := NewService(db)
	h := NewHandler(svc, cfg)
	app := setupTestApp(h, cfg)

	token, _, err := utils.GenerateAccessToken("admin-123", "admin", testJWTSecret, time.Hour)
	if err != nil {
		t.Fatalf("Failed to generate token: %v", err)
	}

	t.Run("GET_Pending_KYC_Success", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/admin/volunteers/pending", nil)
		req.Header.Set("Authorization", "Bearer "+token)

		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("app.Test failed: %v", err)
		}
		if resp.StatusCode != http.StatusOK {
			t.Errorf("Expected status 200 OK, got %d", resp.StatusCode)
		}
	})

	t.Run("GET_Pending_KYC_Pagination", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/admin/volunteers/pending?page=1&limit=5", nil)
		req.Header.Set("Authorization", "Bearer "+token)

		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("app.Test failed: %v", err)
		}
		if resp.StatusCode != http.StatusOK {
			t.Errorf("Expected status 200 OK with pagination, got %d", resp.StatusCode)
		}
		if resp.Header.Get("X-Page") != "1" {
			t.Errorf("Expected header X-Page=1, got %s", resp.Header.Get("X-Page"))
		}
		if resp.Header.Get("X-Limit") != "5" {
			t.Errorf("Expected header X-Limit=5, got %s", resp.Header.Get("X-Limit"))
		}
	})

	t.Run("POST_Approve_NotFound", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/api/v1/admin/volunteers/00000000-0000-0000-0000-000000000000/approve", nil)
		req.Header.Set("Authorization", "Bearer "+token)

		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("app.Test failed: %v", err)
		}
		if resp.StatusCode != http.StatusNotFound {
			t.Errorf("Expected status 404 Not Found, got %d", resp.StatusCode)
		}
	})

	t.Run("POST_Reject_NotFound", func(t *testing.T) {
		body, _ := json.Marshal(RejectKYCRequest{Reason: "Sertifikat kadaluwarsa"})
		req := httptest.NewRequest(http.MethodPost, "/api/v1/admin/volunteers/00000000-0000-0000-0000-000000000000/reject", bytes.NewReader(body))
		req.Header.Set("Authorization", "Bearer "+token)
		req.Header.Set("Content-Type", "application/json")

		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("app.Test failed: %v", err)
		}
		if resp.StatusCode != http.StatusNotFound {
			t.Errorf("Expected status 404 Not Found, got %d", resp.StatusCode)
		}
	})
}

// ─── User Management Tests ───────────────────────────────────────────────────

func TestUserManagement_RBAC_Unauthorized(t *testing.T) {
	cfg := &config.Config{JWTSecret: testJWTSecret}
	h := NewHandler(nil, cfg)
	app := setupTestApp(h, cfg)

	endpoints := []struct {
		method string
		path   string
	}{
		{http.MethodGet, "/api/v1/admin/users"},
		{http.MethodPost, "/api/v1/admin/users/test-id/ban"},
		{http.MethodPost, "/api/v1/admin/users/test-id/unban"},
		{http.MethodDelete, "/api/v1/admin/users/test-id/strike"},
		{http.MethodGet, "/api/v1/admin/users/test-id/detail"},
	}

	for _, ep := range endpoints {
		t.Run(ep.method+" "+ep.path, func(t *testing.T) {
			req := httptest.NewRequest(ep.method, ep.path, nil)
			resp, err := app.Test(req)
			if err != nil {
				t.Fatalf("app.Test failed: %v", err)
			}
			if resp.StatusCode != http.StatusUnauthorized {
				t.Errorf("Expected status 401 Unauthorized, got %d", resp.StatusCode)
			}
		})
	}
}

func TestUserManagement_RBAC_Forbidden_Roles(t *testing.T) {
	cfg := &config.Config{JWTSecret: testJWTSecret}
	h := NewHandler(nil, cfg)
	app := setupTestApp(h, cfg)

	forbiddenRoles := []string{"civilian", "volunteer", "agency", "agency_personnel"}

	for _, role := range forbiddenRoles {
		t.Run("Role_"+role, func(t *testing.T) {
			token, _, err := utils.GenerateAccessToken("user-123", role, testJWTSecret, time.Hour)
			if err != nil {
				t.Fatalf("Failed to generate token: %v", err)
			}

			req := httptest.NewRequest(http.MethodGet, "/api/v1/admin/users", nil)
			req.Header.Set("Authorization", "Bearer "+token)

			resp, err := app.Test(req)
			if err != nil {
				t.Fatalf("app.Test failed: %v", err)
			}
			if resp.StatusCode != http.StatusForbidden {
				t.Errorf("Role %s: expected status 403 Forbidden, got %d", role, resp.StatusCode)
			}
		})
	}
}

func TestUserManagement_BanUser_BadRequest_InvalidJSON(t *testing.T) {
	cfg := &config.Config{JWTSecret: testJWTSecret}
	h := NewHandler(nil, cfg)
	app := setupTestApp(h, cfg)

	token, _, err := utils.GenerateAccessToken("admin-123", "admin", testJWTSecret, time.Hour)
	if err != nil {
		t.Fatalf("Failed to generate token: %v", err)
	}

	invalidBody := bytes.NewReader([]byte("{invalid-json"))
	req := httptest.NewRequest(http.MethodPost, "/api/v1/admin/users/target-456/ban", invalidBody)
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test failed: %v", err)
	}
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("Expected status 400 Bad Request, got %d", resp.StatusCode)
	}
}

func TestUserManagement_WithLiveDB(t *testing.T) {
	db := getOptionalTestDB()
	if db == nil {
		t.Skip("Database testing tidak tersedia — melewati live DB tests")
	}

	cfg := &config.Config{JWTSecret: testJWTSecret}
	svc := NewService(db)
	h := NewHandler(svc, cfg)
	app := setupTestApp(h, cfg)

	token, _, err := utils.GenerateAccessToken("admin-123", "admin", testJWTSecret, time.Hour)
	if err != nil {
		t.Fatalf("Failed to generate token: %v", err)
	}

	t.Run("GET_Users_Success", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/admin/users?role=civilian&banned=false", nil)
		req.Header.Set("Authorization", "Bearer "+token)

		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("app.Test failed: %v", err)
		}
		if resp.StatusCode != http.StatusOK {
			t.Errorf("Expected status 200 OK, got %d", resp.StatusCode)
		}
	})

	t.Run("POST_Ban_NotFound", func(t *testing.T) {
		body, _ := json.Marshal(BanUserRequest{Reason: "Spam SOS berkali-kali", Days: 3})
		req := httptest.NewRequest(http.MethodPost, "/api/v1/admin/users/00000000-0000-0000-0000-000000000000/ban", bytes.NewReader(body))
		req.Header.Set("Authorization", "Bearer "+token)
		req.Header.Set("Content-Type", "application/json")

		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("app.Test failed: %v", err)
		}
		if resp.StatusCode != http.StatusNotFound {
			t.Errorf("Expected status 404 Not Found, got %d", resp.StatusCode)
		}
	})

	t.Run("POST_Unban_NotFound", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/api/v1/admin/users/00000000-0000-0000-0000-000000000000/unban", nil)
		req.Header.Set("Authorization", "Bearer "+token)

		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("app.Test failed: %v", err)
		}
		if resp.StatusCode != http.StatusNotFound {
			t.Errorf("Expected status 404 Not Found, got %d", resp.StatusCode)
		}
	})

	t.Run("DELETE_ResetStrike_NotFound", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodDelete, "/api/v1/admin/users/00000000-0000-0000-0000-000000000000/strike", nil)
		req.Header.Set("Authorization", "Bearer "+token)

		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("app.Test failed: %v", err)
		}
		if resp.StatusCode != http.StatusNotFound {
			t.Errorf("Expected status 404 Not Found, got %d", resp.StatusCode)
		}
	})

	t.Run("GET_UserDetail_NotFound", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/admin/users/00000000-0000-0000-0000-000000000000/detail", nil)
		req.Header.Set("Authorization", "Bearer "+token)

		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("app.Test failed: %v", err)
		}
		if resp.StatusCode != http.StatusNotFound {
			t.Errorf("Expected status 404 Not Found, got %d", resp.StatusCode)
		}
	})
}

// ─── Stats Parameter Normalization Tests ─────────────────────────────────────

func TestAdmin_NormalizePeriod(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"week", "week"},
		{"weekly", "week"},
		{"WEEK", "week"},
		{"  week  ", "week"},
		{"year", "year"},
		{"yearly", "year"},
		{"YEAR", "year"},
		{"month", "month"},
		{"monthly", "month"},
		{"MONTH", "month"},
		{"", "month"},
		{"   ", "month"},
		{"unknown_period", "month"},
	}

	for _, tc := range tests {
		t.Run("Input_"+tc.input, func(t *testing.T) {
			result := normalizePeriod(tc.input)
			if result != tc.expected {
				t.Errorf("normalizePeriod(%q) = %q, expected %q", tc.input, result, tc.expected)
			}
		})
	}
}

// ─── Ranks RBAC Tests ─────────────────────────────────────────────────────────

func TestRanks_RBAC_Unauthorized(t *testing.T) {
	cfg := &config.Config{JWTSecret: testJWTSecret}
	h := NewHandler(nil, cfg)
	app := setupTestApp(h, cfg)

	endpoints := []struct {
		method string
		path   string
	}{
		{http.MethodGet, "/api/v1/admin/ranks"},
		{http.MethodPost, "/api/v1/admin/ranks"},
		{http.MethodPut, "/api/v1/admin/ranks/1"},
		{http.MethodDelete, "/api/v1/admin/ranks/1"},
	}

	for _, ep := range endpoints {
		t.Run(ep.method+" "+ep.path, func(t *testing.T) {
			req := httptest.NewRequest(ep.method, ep.path, nil)
			resp, err := app.Test(req)
			if err != nil {
				t.Fatalf("app.Test failed: %v", err)
			}
			if resp.StatusCode != http.StatusUnauthorized {
				t.Errorf("Expected status 401 Unauthorized, got %d", resp.StatusCode)
			}
		})
	}
}

func TestRanks_RBAC_Forbidden_Roles(t *testing.T) {
	cfg := &config.Config{JWTSecret: testJWTSecret}
	h := NewHandler(nil, cfg)
	app := setupTestApp(h, cfg)

	// Write endpoints require AdminOnly (admin, superadmin)
	writeEndpoints := []struct {
		method string
		path   string
	}{
		{http.MethodPost, "/api/v1/admin/ranks"},
		{http.MethodPut, "/api/v1/admin/ranks/1"},
		{http.MethodDelete, "/api/v1/admin/ranks/1"},
	}

	forbiddenWriteRoles := []string{"civilian", "volunteer", "agency", "agency_personnel"}
	for _, role := range forbiddenWriteRoles {
		t.Run("Write_Forbidden_"+role, func(t *testing.T) {
			token, _, err := utils.GenerateAccessToken("user-123", role, testJWTSecret, time.Hour)
			if err != nil {
				t.Fatalf("Failed to generate token: %v", err)
			}
			for _, ep := range writeEndpoints {
				req := httptest.NewRequest(ep.method, ep.path, nil)
				req.Header.Set("Authorization", "Bearer "+token)
				resp, err := app.Test(req)
				if err != nil {
					t.Fatalf("app.Test failed: %v", err)
				}
				if resp.StatusCode != http.StatusForbidden {
					t.Errorf("[%s] %s %s: expected 403 Forbidden, got %d", role, ep.method, ep.path, resp.StatusCode)
				}
			}
		})
	}

	// Read endpoint GET /ranks requires ConsoleOnly (superadmin, admin, agency)
	forbiddenReadRoles := []string{"civilian", "volunteer", "agency_personnel"}
	for _, role := range forbiddenReadRoles {
		t.Run("Read_Forbidden_"+role, func(t *testing.T) {
			token, _, err := utils.GenerateAccessToken("user-123", role, testJWTSecret, time.Hour)
			if err != nil {
				t.Fatalf("Failed to generate token: %v", err)
			}
			req := httptest.NewRequest(http.MethodGet, "/api/v1/admin/ranks", nil)
			req.Header.Set("Authorization", "Bearer "+token)
			resp, err := app.Test(req)
			if err != nil {
				t.Fatalf("app.Test failed: %v", err)
			}
			if resp.StatusCode != http.StatusForbidden {
				t.Errorf("[%s] GET /admin/ranks: expected 403 Forbidden, got %d", role, resp.StatusCode)
			}
		})
	}
}

// ─── Stats RBAC Tests ─────────────────────────────────────────────────────────

func TestStats_RBAC_Unauthorized(t *testing.T) {
	cfg := &config.Config{JWTSecret: testJWTSecret}
	h := NewHandler(nil, cfg)
	app := setupTestApp(h, cfg)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/admin/stats", nil)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test failed: %v", err)
	}
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("Expected status 401 Unauthorized, got %d", resp.StatusCode)
	}
}

func TestStats_RBAC_Forbidden_Roles(t *testing.T) {
	cfg := &config.Config{JWTSecret: testJWTSecret}
	h := NewHandler(nil, cfg)
	app := setupTestApp(h, cfg)

	forbiddenRoles := []string{"civilian", "volunteer", "agency_personnel"}
	for _, role := range forbiddenRoles {
		t.Run("Role_"+role, func(t *testing.T) {
			token, _, err := utils.GenerateAccessToken("user-123", role, testJWTSecret, time.Hour)
			if err != nil {
				t.Fatalf("Failed to generate token: %v", err)
			}

			req := httptest.NewRequest(http.MethodGet, "/api/v1/admin/stats", nil)
			req.Header.Set("Authorization", "Bearer "+token)

			resp, err := app.Test(req)
			if err != nil {
				t.Fatalf("app.Test failed: %v", err)
			}
			if resp.StatusCode != http.StatusForbidden {
				t.Errorf("Role %s: expected status 403 Forbidden, got %d", role, resp.StatusCode)
			}
		})
	}
}

// ─── Rank Validation & Service Unit Tests ─────────────────────────────────────

func TestRanks_Validation_BadRequest(t *testing.T) {
	cfg := &config.Config{JWTSecret: testJWTSecret}
	h := NewHandler(nil, cfg)
	app := setupTestApp(h, cfg)

	token, _, err := utils.GenerateAccessToken("admin-123", "admin", testJWTSecret, time.Hour)
	if err != nil {
		t.Fatalf("Failed to generate token: %v", err)
	}

	t.Run("Create_InvalidJSON", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/api/v1/admin/ranks", bytes.NewReader([]byte("{invalid-json")))
		req.Header.Set("Authorization", "Bearer "+token)
		req.Header.Set("Content-Type", "application/json")
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("app.Test failed: %v", err)
		}
		if resp.StatusCode != http.StatusBadRequest {
			t.Errorf("Expected 400 Bad Request, got %d", resp.StatusCode)
		}
	})

	t.Run("Update_InvalidID", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPut, "/api/v1/admin/ranks/not-a-number", bytes.NewReader([]byte("{}")))
		req.Header.Set("Authorization", "Bearer "+token)
		req.Header.Set("Content-Type", "application/json")
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("app.Test failed: %v", err)
		}
		if resp.StatusCode != http.StatusBadRequest {
			t.Errorf("Expected 400 Bad Request for non-integer ID, got %d", resp.StatusCode)
		}
	})

	t.Run("Delete_InvalidID", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodDelete, "/api/v1/admin/ranks/not-a-number", nil)
		req.Header.Set("Authorization", "Bearer "+token)
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("app.Test failed: %v", err)
		}
		if resp.StatusCode != http.StatusBadRequest {
			t.Errorf("Expected 400 Bad Request for non-integer ID, got %d", resp.StatusCode)
		}
	})
}

func TestRanks_Service_Validation(t *testing.T) {
	svc := &Service{}

	t.Run("CreateRank_EmptyName", func(t *testing.T) {
		_, err := svc.CreateRank(&RankRequest{RankName: "   ", MinExp: 100})
		if err == nil || err.Error() != "rank_name wajib diisi" {
			t.Errorf("Expected error 'rank_name wajib diisi', got %v", err)
		}
	})

	t.Run("CreateRank_NegativeMinExp", func(t *testing.T) {
		_, err := svc.CreateRank(&RankRequest{RankName: "Siswa", MinExp: -10})
		if err == nil || err.Error() != "min_exp tidak boleh negatif" {
			t.Errorf("Expected error 'min_exp tidak boleh negatif', got %v", err)
		}
	})

	t.Run("UpdateRank_EmptyName", func(t *testing.T) {
		_, err := svc.UpdateRank(1, &RankRequest{RankName: "", MinExp: 100})
		if err == nil || err.Error() != "rank_name wajib diisi" {
			t.Errorf("Expected error 'rank_name wajib diisi', got %v", err)
		}
	})

	t.Run("UpdateRank_NegativeMinExp", func(t *testing.T) {
		_, err := svc.UpdateRank(1, &RankRequest{RankName: "Siswa", MinExp: -1})
		if err == nil || err.Error() != "min_exp tidak boleh negatif" {
			t.Errorf("Expected error 'min_exp tidak boleh negatif', got %v", err)
		}
	})

	t.Run("CreateBadge_EmptyName", func(t *testing.T) {
		_, err := svc.CreateBadge(&BadgeRequest{BadgeName: ""})
		if err == nil || err.Error() != "badge_name wajib diisi" {
			t.Errorf("Expected error 'badge_name wajib diisi', got %v", err)
		}
	})
}

// ─── Live Database Tests for Ranks & Stats ───────────────────────────────────

func TestRanksAndStats_WithLiveDB(t *testing.T) {
	db := getOptionalTestDB()
	if db == nil {
		t.Skip("Database testing tidak tersedia — melewati live DB tests")
	}

	cfg := &config.Config{JWTSecret: testJWTSecret}
	svc := NewService(db)
	h := NewHandler(svc, cfg)
	app := setupTestApp(h, cfg)

	token, _, err := utils.GenerateAccessToken("admin-123", "admin", testJWTSecret, time.Hour)
	if err != nil {
		t.Fatalf("Failed to generate token: %v", err)
	}

	// Clean up any test ranks from previous runs
	cleanupRanks := func() {
		db.Exec("DELETE FROM volunteer_reputation WHERE rank_id IN (SELECT id FROM m_ranks WHERE rank_name LIKE 'TestRank_%')")
		db.Exec("DELETE FROM m_ranks WHERE rank_name LIKE 'TestRank_%'")
	}
	cleanupRanks()
	defer cleanupRanks()

	var baseRankID int
	var tier1RankID int
	var tier2RankID int

	t.Run("1_CreateRank_BaseRank", func(t *testing.T) {
		// Check if a base rank already exists
		var existing MRank
		if err := db.Where("min_exp = 0").First(&existing).Error; err == nil {
			baseRankID = existing.ID
		} else {
			body, _ := json.Marshal(RankRequest{
				RankName: "TestRank_Base",
				MinExp:   0,
			})
			req := httptest.NewRequest(http.MethodPost, "/api/v1/admin/ranks", bytes.NewReader(body))
			req.Header.Set("Authorization", "Bearer "+token)
			req.Header.Set("Content-Type", "application/json")

			resp, err := app.Test(req)
			if err != nil {
				t.Fatalf("app.Test failed: %v", err)
			}
			if resp.StatusCode != http.StatusCreated {
				t.Fatalf("Expected 201 Created for base rank, got %d", resp.StatusCode)
			}

			var created MRank
			if err := db.Where("min_exp = 0").First(&created).Error; err != nil {
				t.Fatalf("Failed to find created base rank in DB: %v", err)
			}
			baseRankID = created.ID
		}
	})

	t.Run("2_CreateRank_DuplicateMinExp_Rejected", func(t *testing.T) {
		body, _ := json.Marshal(RankRequest{
			RankName: "TestRank_DuplicateBase",
			MinExp:   0,
		})
		req := httptest.NewRequest(http.MethodPost, "/api/v1/admin/ranks", bytes.NewReader(body))
		req.Header.Set("Authorization", "Bearer "+token)
		req.Header.Set("Content-Type", "application/json")

		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("app.Test failed: %v", err)
		}
		if resp.StatusCode != http.StatusBadRequest {
			t.Errorf("Expected 400 Bad Request for duplicate min_exp 0, got %d", resp.StatusCode)
		}
	})

	t.Run("3_CreateRank_Tier1_Success", func(t *testing.T) {
		body, _ := json.Marshal(RankRequest{
			RankName: "TestRank_Tier1",
			MinExp:   100,
		})
		req := httptest.NewRequest(http.MethodPost, "/api/v1/admin/ranks", bytes.NewReader(body))
		req.Header.Set("Authorization", "Bearer "+token)
		req.Header.Set("Content-Type", "application/json")

		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("app.Test failed: %v", err)
		}
		if resp.StatusCode != http.StatusCreated {
			t.Fatalf("Expected 201 Created for Tier1 rank, got %d", resp.StatusCode)
		}

		var created MRank
		if err := db.Where("LOWER(rank_name) = LOWER('TestRank_Tier1')").First(&created).Error; err != nil {
			t.Fatalf("Failed to find created Tier1 rank in DB: %v", err)
		}
		tier1RankID = created.ID
	})

	t.Run("4_CreateRank_DuplicateName_CaseInsensitive_Rejected", func(t *testing.T) {
		body, _ := json.Marshal(RankRequest{
			RankName: "testrank_tier1", // lowercase of existing TestRank_Tier1
			MinExp:   250,
		})
		req := httptest.NewRequest(http.MethodPost, "/api/v1/admin/ranks", bytes.NewReader(body))
		req.Header.Set("Authorization", "Bearer "+token)
		req.Header.Set("Content-Type", "application/json")

		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("app.Test failed: %v", err)
		}
		if resp.StatusCode != http.StatusBadRequest {
			t.Errorf("Expected 400 Bad Request for case-insensitive duplicate name, got %d", resp.StatusCode)
		}
	})

	t.Run("5_CreateRank_Tier2_Success", func(t *testing.T) {
		body, _ := json.Marshal(RankRequest{
			RankName: "TestRank_Tier2",
			MinExp:   300,
		})
		req := httptest.NewRequest(http.MethodPost, "/api/v1/admin/ranks", bytes.NewReader(body))
		req.Header.Set("Authorization", "Bearer "+token)
		req.Header.Set("Content-Type", "application/json")

		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("app.Test failed: %v", err)
		}
		if resp.StatusCode != http.StatusCreated {
			t.Fatalf("Expected 201 Created for Tier2 rank, got %d", resp.StatusCode)
		}

		var created MRank
		if err := db.Where("LOWER(rank_name) = LOWER('TestRank_Tier2')").First(&created).Error; err != nil {
			t.Fatalf("Failed to find created Tier2 rank in DB: %v", err)
		}
		tier2RankID = created.ID
	})

	t.Run("6_UpdateRank_BaseRank_NonZeroMinExp_Rejected", func(t *testing.T) {
		body, _ := json.Marshal(RankRequest{
			RankName: "TestRank_Base_Renamed",
			MinExp:   50, // base rank cannot have min_exp > 0
		})
		req := httptest.NewRequest(http.MethodPut, fmt.Sprintf("/api/v1/admin/ranks/%d", baseRankID), bytes.NewReader(body))
		req.Header.Set("Authorization", "Bearer "+token)
		req.Header.Set("Content-Type", "application/json")

		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("app.Test failed: %v", err)
		}
		if resp.StatusCode != http.StatusBadRequest {
			t.Errorf("Expected 400 Bad Request when updating base rank min_exp to non-zero, got %d", resp.StatusCode)
		}
	})

	t.Run("7_UpdateRank_DuplicateName_Rejected", func(t *testing.T) {
		body, _ := json.Marshal(RankRequest{
			RankName: "testrank_tier2", // collides with Tier2
			MinExp:   100,
		})
		req := httptest.NewRequest(http.MethodPut, fmt.Sprintf("/api/v1/admin/ranks/%d", tier1RankID), bytes.NewReader(body))
		req.Header.Set("Authorization", "Bearer "+token)
		req.Header.Set("Content-Type", "application/json")

		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("app.Test failed: %v", err)
		}
		if resp.StatusCode != http.StatusBadRequest {
			t.Errorf("Expected 400 Bad Request when updating rank to duplicate name, got %d", resp.StatusCode)
		}
	})

	t.Run("8_UpdateRank_DuplicateMinExp_Rejected", func(t *testing.T) {
		body, _ := json.Marshal(RankRequest{
			RankName: "TestRank_Tier1_Unique",
			MinExp:   300, // collides with Tier2 min_exp
		})
		req := httptest.NewRequest(http.MethodPut, fmt.Sprintf("/api/v1/admin/ranks/%d", tier1RankID), bytes.NewReader(body))
		req.Header.Set("Authorization", "Bearer "+token)
		req.Header.Set("Content-Type", "application/json")

		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("app.Test failed: %v", err)
		}
		if resp.StatusCode != http.StatusBadRequest {
			t.Errorf("Expected 400 Bad Request when updating rank to duplicate min_exp, got %d", resp.StatusCode)
		}
	})

	t.Run("9_UpdateRank_NotFound", func(t *testing.T) {
		body, _ := json.Marshal(RankRequest{
			RankName: "TestRank_NonExistent",
			MinExp:   999,
		})
		req := httptest.NewRequest(http.MethodPut, "/api/v1/admin/ranks/999999", bytes.NewReader(body))
		req.Header.Set("Authorization", "Bearer "+token)
		req.Header.Set("Content-Type", "application/json")

		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("app.Test failed: %v", err)
		}
		if resp.StatusCode != http.StatusNotFound {
			t.Errorf("Expected 404 Not Found for non-existent rank update, got %d", resp.StatusCode)
		}
	})

	t.Run("10_DeleteRank_BaseRank_Forbidden", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodDelete, fmt.Sprintf("/api/v1/admin/ranks/%d", baseRankID), nil)
		req.Header.Set("Authorization", "Bearer "+token)

		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("app.Test failed: %v", err)
		}
		if resp.StatusCode != http.StatusBadRequest {
			t.Errorf("Expected 400 Bad Request when attempting to delete base rank (min_exp = 0), got %d", resp.StatusCode)
		}
	})

	t.Run("11_DeleteRank_NotFound", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodDelete, "/api/v1/admin/ranks/999999", nil)
		req.Header.Set("Authorization", "Bearer "+token)

		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("app.Test failed: %v", err)
		}
		if resp.StatusCode != http.StatusNotFound {
			t.Errorf("Expected 404 Not Found when deleting non-existent rank, got %d", resp.StatusCode)
		}
	})

	t.Run("12_DeleteRank_AutoDowngrade_Success", func(t *testing.T) {
		// Create a test volunteer holding Tier 2 rank
		dummyUserID := "00000000-0000-0000-0000-000000000077"
		db.Exec(`INSERT INTO users (id, email, password_hash, role) 
		         VALUES (?, 'vol_test77@example.com', 'hash', 'volunteer') 
		         ON CONFLICT (id) DO NOTHING`, dummyUserID)
		db.Exec(`INSERT INTO volunteer_reputation (user_id, exp_points, rank_id) 
		         VALUES (?, 350, ?) 
		         ON CONFLICT (user_id) DO UPDATE SET rank_id = EXCLUDED.rank_id`, dummyUserID, tier2RankID)

		defer func() {
			db.Exec("DELETE FROM volunteer_reputation WHERE user_id = ?", dummyUserID)
			db.Exec("DELETE FROM users WHERE id = ?", dummyUserID)
		}()

		// Delete Tier 2 rank -> should auto-downgrade to Tier 1
		req := httptest.NewRequest(http.MethodDelete, fmt.Sprintf("/api/v1/admin/ranks/%d", tier2RankID), nil)
		req.Header.Set("Authorization", "Bearer "+token)

		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("app.Test failed: %v", err)
		}
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("Expected 200 OK for rank deletion with auto-downgrade, got %d", resp.StatusCode)
		}

		// Verify volunteer was downgraded to Tier 1
		var currentRankID int
		err = db.Raw("SELECT rank_id FROM volunteer_reputation WHERE user_id = ?", dummyUserID).Scan(&currentRankID).Error
		if err != nil {
			t.Fatalf("Failed to query volunteer reputation after downgrade: %v", err)
		}
		if currentRankID != tier1RankID {
			t.Errorf("Expected volunteer rank to be downgraded to Tier 1 (%d), got %d", tier1RankID, currentRankID)
		}
	})

	t.Run("13_GetStats_AllPeriods", func(t *testing.T) {
		periods := []string{"", "week", "month", "year", "weekly", "monthly", "yearly"}
		for _, p := range periods {
			url := "/api/v1/admin/stats"
			if p != "" {
				url += "?period=" + p
			}
			req := httptest.NewRequest(http.MethodGet, url, nil)
			req.Header.Set("Authorization", "Bearer "+token)

			resp, err := app.Test(req)
			if err != nil {
				t.Fatalf("app.Test failed for period %q: %v", p, err)
			}
			if resp.StatusCode != http.StatusOK {
				t.Errorf("Expected 200 OK for GET %s, got %d", url, resp.StatusCode)
			}

			var body struct {
				Success bool          `json:"success"`
				Data    StatsResponse `json:"data"`
			}
			if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
				t.Errorf("Failed to decode stats response for period %q: %v", p, err)
			}
			if !body.Success {
				t.Errorf("Expected success = true for period %q", p)
			}
			// ActiveVolunteers must be non-negative (global count)
			if body.Data.ActiveVolunteers < 0 {
				t.Errorf("Active volunteers should be >= 0, got %d", body.Data.ActiveVolunteers)
			}
		}
	})
}
