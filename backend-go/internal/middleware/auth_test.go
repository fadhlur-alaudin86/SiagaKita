package middleware

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"siagakita-backend/internal/config"
	"siagakita-backend/internal/utils"

	"github.com/gofiber/fiber/v2"
)

func TestAuth_MissingHeader(t *testing.T) {
	cfg := &config.Config{JWTSecret: "test-secret-key"}
	app := fiber.New()
	app.Get("/protected", Auth(cfg), func(c *fiber.Ctx) error {
		return c.SendString("ok")
	})

	req := httptest.NewRequest(http.MethodGet, "/protected", nil)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test failed: %v", err)
	}

	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("expected 401 Unauthorized, got %d", resp.StatusCode)
	}

	body, _ := io.ReadAll(resp.Body)
	var res utils.APIResponse
	_ = json.Unmarshal(body, &res)
	if res.Success {
		t.Errorf("expected Success false")
	}
}

func TestAuth_InvalidBearerPrefix(t *testing.T) {
	cfg := &config.Config{JWTSecret: "test-secret-key"}
	app := fiber.New()
	app.Get("/protected", Auth(cfg), func(c *fiber.Ctx) error {
		return c.SendString("ok")
	})

	req := httptest.NewRequest(http.MethodGet, "/protected", nil)
	req.Header.Set("Authorization", "Basic user:pass")
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test failed: %v", err)
	}

	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("expected 401 Unauthorized, got %d", resp.StatusCode)
	}
}

func TestAuth_InvalidOrExpiredToken(t *testing.T) {
	cfg := &config.Config{JWTSecret: "test-secret-key"}
	app := fiber.New()
	app.Get("/protected", Auth(cfg), func(c *fiber.Ctx) error {
		return c.SendString("ok")
	})

	// 1. Expired token
	expiredToken, _, _ := utils.GenerateAccessToken("user-1", "civilian", cfg.JWTSecret, -1*time.Hour)
	reqExpired := httptest.NewRequest(http.MethodGet, "/protected", nil)
	reqExpired.Header.Set("Authorization", "Bearer "+expiredToken)
	respExpired, err := app.Test(reqExpired)
	if err != nil {
		t.Fatalf("app.Test failed: %v", err)
	}
	if respExpired.StatusCode != http.StatusUnauthorized {
		t.Errorf("expected 401 for expired token, got %d", respExpired.StatusCode)
	}

	// 2. Tampered token
	reqTampered := httptest.NewRequest(http.MethodGet, "/protected", nil)
	reqTampered.Header.Set("Authorization", "Bearer forged-garbage-token")
	respTampered, err := app.Test(reqTampered)
	if err != nil {
		t.Fatalf("app.Test failed: %v", err)
	}
	if respTampered.StatusCode != http.StatusUnauthorized {
		t.Errorf("expected 401 for tampered token, got %d", respTampered.StatusCode)
	}
}

func TestAuth_ValidToken(t *testing.T) {
	cfg := &config.Config{JWTSecret: "test-secret-key"}
	app := fiber.New()

	var extractedUserID, extractedRole, extractedJTI string
	app.Get("/protected", Auth(cfg), func(c *fiber.Ctx) error {
		extractedUserID, _ = c.Locals("userID").(string)
		extractedRole, _ = c.Locals("userRole").(string)
		extractedJTI, _ = c.Locals("userJTI").(string)
		return c.SendString("access-granted")
	})

	validToken, expectedJTI, err := utils.GenerateAccessToken("user-uuid-999", "admin", cfg.JWTSecret, 15*time.Minute)
	if err != nil {
		t.Fatalf("token generation failed: %v", err)
	}

	req := httptest.NewRequest(http.MethodGet, "/protected", nil)
	req.Header.Set("Authorization", "Bearer "+validToken)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test failed: %v", err)
	}

	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200 OK, got %d", resp.StatusCode)
	}
	if extractedUserID != "user-uuid-999" {
		t.Errorf("expected userID 'user-uuid-999', got %q", extractedUserID)
	}
	if extractedRole != "admin" {
		t.Errorf("expected role 'admin', got %q", extractedRole)
	}
	if extractedJTI != expectedJTI {
		t.Errorf("expected JTI %q, got %q", expectedJTI, extractedJTI)
	}
}

func TestAPIKeyGateway(t *testing.T) {
	cfg := &config.Config{SMSGatewaySecret: "secret-sms-gateway-key"}
	app := fiber.New()
	app.Post("/gateway/sms", APIKeyGateway(cfg), func(c *fiber.Ctx) error {
		return c.SendString("sms-received")
	})

	// 1. Missing secret
	reqMissing := httptest.NewRequest(http.MethodPost, "/gateway/sms", nil)
	respMissing, err := app.Test(reqMissing)
	if err != nil {
		t.Fatalf("app.Test failed: %v", err)
	}
	if respMissing.StatusCode != http.StatusUnauthorized {
		t.Errorf("expected 401 for missing secret, got %d", respMissing.StatusCode)
	}

	// 2. Wrong secret
	reqWrong := httptest.NewRequest(http.MethodPost, "/gateway/sms", nil)
	reqWrong.Header.Set("X-Gateway-Secret", "wrong-secret")
	respWrong, err := app.Test(reqWrong)
	if err != nil {
		t.Fatalf("app.Test failed: %v", err)
	}
	if respWrong.StatusCode != http.StatusUnauthorized {
		t.Errorf("expected 401 for wrong secret, got %d", respWrong.StatusCode)
	}

	// 3. Valid secret
	reqValid := httptest.NewRequest(http.MethodPost, "/gateway/sms", nil)
	reqValid.Header.Set("X-Gateway-Secret", "secret-sms-gateway-key")
	respValid, err := app.Test(reqValid)
	if err != nil {
		t.Fatalf("app.Test failed: %v", err)
	}
	if respValid.StatusCode != http.StatusOK {
		t.Errorf("expected 200 for valid secret, got %d", respValid.StatusCode)
	}
}

func TestRequireRoles(t *testing.T) {
	app := fiber.New()
	app.Get("/admin-only", func(c *fiber.Ctx) error {
		// Mock role injection simulating Auth middleware
		role := c.Get("X-Mock-Role")
		if role != "" {
			c.Locals("userRole", role)
		}
		return c.Next()
	}, RequireRoles("admin", "superadmin"), func(c *fiber.Ctx) error {
		return c.SendString("welcome-admin")
	})

	// 1. Unauthenticated (no userRole) -> returns 403 Forbidden
	reqUnauth := httptest.NewRequest(http.MethodGet, "/admin-only", nil)
	respUnauth, err := app.Test(reqUnauth)
	if err != nil {
		t.Fatalf("app.Test failed: %v", err)
	}
	if respUnauth.StatusCode != http.StatusForbidden {
		t.Errorf("expected 403 for unauthenticated request without role, got %d", respUnauth.StatusCode)
	}

	// 2. Unauthorized role (civilian) -> returns 403 Forbidden
	reqCivilian := httptest.NewRequest(http.MethodGet, "/admin-only", nil)
	reqCivilian.Header.Set("X-Mock-Role", "civilian")
	respCivilian, err := app.Test(reqCivilian)
	if err != nil {
		t.Fatalf("app.Test failed: %v", err)
	}
	if respCivilian.StatusCode != http.StatusForbidden {
		t.Errorf("expected 403 for unauthorized role, got %d", respCivilian.StatusCode)
	}

	// 3. Authorized role (admin)
	reqAdmin := httptest.NewRequest(http.MethodGet, "/admin-only", nil)
	reqAdmin.Header.Set("X-Mock-Role", "admin")
	respAdmin, err := app.Test(reqAdmin)
	if err != nil {
		t.Fatalf("app.Test failed: %v", err)
	}
	if respAdmin.StatusCode != http.StatusOK {
		t.Errorf("expected 200 for authorized role, got %d", respAdmin.StatusCode)
	}

	// 4. Authorized role (superadmin)
	reqSuperadmin := httptest.NewRequest(http.MethodGet, "/admin-only", nil)
	reqSuperadmin.Header.Set("X-Mock-Role", "superadmin")
	respSuperadmin, err := app.Test(reqSuperadmin)
	if err != nil {
		t.Fatalf("app.Test failed: %v", err)
	}
	if respSuperadmin.StatusCode != http.StatusOK {
		t.Errorf("expected 200 for authorized superadmin, got %d", respSuperadmin.StatusCode)
	}
}

func TestRoleShorthands(t *testing.T) {
	app := fiber.New()
	app.Use(func(c *fiber.Ctx) error {
		if r := c.Get("X-Mock-Role"); r != "" {
			c.Locals("userRole", r)
		}
		return c.Next()
	})

	app.Get("/superadmin", SuperAdminOnly(), func(c *fiber.Ctx) error { return c.SendString("ok") })
	app.Get("/admin", AdminOnly(), func(c *fiber.Ctx) error { return c.SendString("ok") })
	app.Get("/console", ConsoleOnly(), func(c *fiber.Ctx) error { return c.SendString("ok") })

	// SuperAdminOnly allows superadmin, blocks admin
	reqSA := httptest.NewRequest(http.MethodGet, "/superadmin", nil)
	reqSA.Header.Set("X-Mock-Role", "superadmin")
	respSA, _ := app.Test(reqSA)
	if respSA.StatusCode != http.StatusOK {
		t.Errorf("SuperAdminOnly expected 200 for superadmin, got %d", respSA.StatusCode)
	}

	reqSAFail := httptest.NewRequest(http.MethodGet, "/superadmin", nil)
	reqSAFail.Header.Set("X-Mock-Role", "admin")
	respSAFail, _ := app.Test(reqSAFail)
	if respSAFail.StatusCode != http.StatusForbidden {
		t.Errorf("SuperAdminOnly expected 403 for admin, got %d", respSAFail.StatusCode)
	}

	// AdminOnly allows admin and superadmin
	reqAdmin := httptest.NewRequest(http.MethodGet, "/admin", nil)
	reqAdmin.Header.Set("X-Mock-Role", "admin")
	respAdmin, _ := app.Test(reqAdmin)
	if respAdmin.StatusCode != http.StatusOK {
		t.Errorf("AdminOnly expected 200 for admin, got %d", respAdmin.StatusCode)
	}

	// ConsoleOnly allows agency
	reqConsole := httptest.NewRequest(http.MethodGet, "/console", nil)
	reqConsole.Header.Set("X-Mock-Role", "agency")
	respConsole, _ := app.Test(reqConsole)
	if respConsole.StatusCode != http.StatusOK {
		t.Errorf("ConsoleOnly expected 200 for agency, got %d", respConsole.StatusCode)
	}
}

func TestIdempotency_BypassNonStateChanging(t *testing.T) {
	// Nil redis client should not panic for GET/OPTIONS methods or empty header
	app := fiber.New()
	app.Use(Idempotency(nil))
	app.Get("/resource", func(c *fiber.Ctx) error {
		return c.SendString("get-ok")
	})
	app.Post("/resource", func(c *fiber.Ctx) error {
		return c.SendString("post-ok")
	})

	// 1. GET with key should bypass without accessing Redis
	reqGet := httptest.NewRequest(http.MethodGet, "/resource", nil)
	reqGet.Header.Set("X-Idempotency-Key", "key-123")
	respGet, err := app.Test(reqGet)
	if err != nil {
		t.Fatalf("GET request failed: %v", err)
	}
	if respGet.StatusCode != http.StatusOK {
		t.Errorf("expected 200 OK, got %d", respGet.StatusCode)
	}

	// 2. POST without key should bypass without accessing Redis
	reqPost := httptest.NewRequest(http.MethodPost, "/resource", nil)
	respPost, err := app.Test(reqPost)
	if err != nil {
		t.Fatalf("POST request without key failed: %v", err)
	}
	if respPost.StatusCode != http.StatusOK {
		t.Errorf("expected 200 OK, got %d", respPost.StatusCode)
	}
}

func TestBanCheck_NoUser(t *testing.T) {
	app := fiber.New()
	app.Get("/sos", BanCheck(nil), func(c *fiber.Ctx) error {
		return c.SendString("sos-ok")
	})

	req := httptest.NewRequest(http.MethodGet, "/sos", nil)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200 OK for unauthenticated/empty user, got %d", resp.StatusCode)
	}
}
