package user

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"siagakita-backend/internal/config"
	"siagakita-backend/internal/utils"

	"github.com/gofiber/fiber/v2"
)

func setupTestApp(h *Handler) *fiber.App {
	app := fiber.New()
	auth := app.Group("/api/v1/auth")
	auth.Post("/refresh-token", h.RefreshToken)
	return app
}

const (
	fieldRefreshToken = "refresh_token"
	testJWTSecret     = "test-jwt-secret-key-32-chars-long!"
)

func TestRefreshToken_Handler(t *testing.T) {
	cfg := &config.Config{
		JWTSecret:     testJWTSecret,
		JWTAccessTTL:  15 * time.Minute,
		JWTRefreshTTL: 7 * 24 * time.Hour,
	}
	svc := &Service{cfg: cfg}
	h := NewHandler(svc)
	app := setupTestApp(h)

	t.Run("BadRequest_InvalidJSON", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/refresh-token", bytes.NewReader([]byte("{invalid-json")))
		req.Header.Set("Content-Type", "application/json")
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if resp.StatusCode != http.StatusBadRequest {
			t.Errorf("expected 400, got %d", resp.StatusCode)
		}
	})

	t.Run("BadRequest_EmptyRefreshToken", func(t *testing.T) {
		body, _ := json.Marshal(map[string]string{fieldRefreshToken: ""})
		req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/refresh-token", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if resp.StatusCode != http.StatusBadRequest {
			t.Errorf("expected 400, got %d", resp.StatusCode)
		}
	})

	t.Run("Unauthorized_InvalidToken", func(t *testing.T) {
		body, _ := json.Marshal(map[string]string{fieldRefreshToken: "invalid.jwt.token"})
		req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/refresh-token", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if resp.StatusCode != http.StatusUnauthorized {
			t.Errorf("expected 401, got %d", resp.StatusCode)
		}
	})

	t.Run("Unauthorized_AccessTokenPassed", func(t *testing.T) {
		accessToken, _, _ := utils.GenerateAccessToken("user-1", "civilian", cfg.JWTSecret, cfg.JWTAccessTTL)
		body, _ := json.Marshal(map[string]string{fieldRefreshToken: accessToken})
		req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/refresh-token", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if resp.StatusCode != http.StatusUnauthorized {
			t.Errorf("expected 401, got %d", resp.StatusCode)
		}
	})
}
