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
