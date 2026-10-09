package user

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
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
	auth.Post("/personnel/login", h.PersonnelLogin)
	return app
}

const (
	fieldRefreshToken = "refresh_token"
	testJWTSecret     = "test-jwt-secret-key-32-chars-long!"
)

func TestRegister_DuplicateContract(t *testing.T) {
	// Service wraps duplicates around sentinels; handlers map them to 409 codes.
	if !errors.Is(fmt.Errorf("wrap: %w", ErrEmailTaken), ErrEmailTaken) {
		t.Errorf("ErrEmailTaken must survive wrapping")
	}
	nikErr := fmt.Errorf("NIK ini sudah terdaftar pada akun lain: %w", ErrNIKAlreadyUsed)
	if !errors.Is(nikErr, ErrNIKAlreadyUsed) {
		t.Errorf("ErrNIKAlreadyUsed must survive wrapping")
	}

	// Validation path carries the default 400 code without touching the DB.
	cfg := &config.Config{}
	h := NewHandler(&Service{cfg: cfg})
	app := fiber.New()
	app.Post("/api/v1/auth/register", h.Register)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/register", bytes.NewReader([]byte("{invalid-json")))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", resp.StatusCode)
	}
	body, _ := io.ReadAll(resp.Body)
	var res utils.APIResponse
	_ = json.Unmarshal(body, &res)
	if res.Code != "ERR_BAD_REQUEST" {
		t.Errorf("expected code ERR_BAD_REQUEST, got %q", res.Code)
	}

	// Same request in English: message translates, code stays identical.
	reqEN := httptest.NewRequest(http.MethodPost, "/api/v1/auth/register", bytes.NewReader([]byte("{invalid-json")))
	reqEN.Header.Set("Content-Type", "application/json")
	reqEN.Header.Set("Accept-Language", "en")
	respEN, err := app.Test(reqEN)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	bodyEN, _ := io.ReadAll(respEN.Body)
	var resEN utils.APIResponse
	_ = json.Unmarshal(bodyEN, &resEN)
	if resEN.Code != "ERR_BAD_REQUEST" {
		t.Errorf("expected code ERR_BAD_REQUEST in en, got %q", resEN.Code)
	}
	if resEN.Message != "Invalid request body" {
		t.Errorf("expected English message, got %q", resEN.Message)
	}
}

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

func TestPersonnelLogin_Handler(t *testing.T) {
	cfg := &config.Config{
		JWTSecret:     testJWTSecret,
		JWTAccessTTL:  15 * time.Minute,
		JWTRefreshTTL: 7 * 24 * time.Hour,
	}
	svc := &Service{cfg: cfg}
	h := NewHandler(svc)
	app := setupTestApp(h)

	t.Run("BadRequest_InvalidJSON", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/personnel/login", bytes.NewReader([]byte("{invalid-json")))
		req.Header.Set("Content-Type", "application/json")
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if resp.StatusCode != http.StatusBadRequest {
			t.Errorf("expected 400, got %d", resp.StatusCode)
		}
	})

	t.Run("Unauthorized_EmptyCredentials", func(t *testing.T) {
		body, _ := json.Marshal(map[string]string{"email": "", "password": ""})
		req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/personnel/login", bytes.NewReader(body))
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
