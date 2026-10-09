package utils

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gofiber/fiber/v2"
)

func TestSuccessResponse(t *testing.T) {
	app := fiber.New()
	app.Get("/test-success", func(c *fiber.Ctx) error {
		return SuccessResponse(c, fiber.Map{"item": "sensor-1"})
	})

	req := httptest.NewRequest(http.MethodGet, "/test-success", nil)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test failed: %v", err)
	}

	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200 OK, got %d", resp.StatusCode)
	}

	body, _ := io.ReadAll(resp.Body)
	var res APIResponse
	if err := json.Unmarshal(body, &res); err != nil {
		t.Fatalf("failed to unmarshal JSON: %v", err)
	}

	if !res.Success {
		t.Errorf("expected Success to be true")
	}
	dataMap, ok := res.Data.(map[string]interface{})
	if !ok || dataMap["item"] != "sensor-1" {
		t.Errorf("expected data.item to be 'sensor-1', got %+v", res.Data)
	}
}

func TestSuccessResponse_WithMapTranslation(t *testing.T) {
	app := fiber.New()
	app.Get("/test-map-i18n", func(c *fiber.Ctx) error {
		return SuccessResponse(c, fiber.Map{
			"message": "Registrasi berhasil",
			"status":  "active",
		})
	})

	req := httptest.NewRequest(http.MethodGet, "/test-map-i18n", nil)
	req.Header.Set("Accept-Language", "en")
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test failed: %v", err)
	}

	body, _ := io.ReadAll(resp.Body)
	var res APIResponse
	if err := json.Unmarshal(body, &res); err != nil {
		t.Fatalf("failed to unmarshal JSON: %v", err)
	}

	dataMap, ok := res.Data.(map[string]interface{})
	if !ok {
		t.Fatalf("expected data to be map, got %+v", res.Data)
	}

	if dataMap["message"] != "Registration successful" {
		t.Errorf("expected translated message 'Registration successful', got %v", dataMap["message"])
	}
}

func TestSuccessResponseWithMsg(t *testing.T) {
	app := fiber.New()
	app.Get("/test-msg", func(c *fiber.Ctx) error {
		return SuccessResponseWithMsg(c, "Registrasi berhasil", fiber.Map{"id": 42})
	})

	// 1. Indonesian locale (default)
	reqID := httptest.NewRequest(http.MethodGet, "/test-msg", nil)
	respID, err := app.Test(reqID)
	if err != nil {
		t.Fatalf("app.Test failed: %v", err)
	}
	bodyID, _ := io.ReadAll(respID.Body)
	var resID APIResponse
	_ = json.Unmarshal(bodyID, &resID)
	if resID.Message != "Registrasi berhasil" {
		t.Errorf("expected Indonesian message 'Registrasi berhasil', got %q", resID.Message)
	}

	// 2. English locale
	reqEN := httptest.NewRequest(http.MethodGet, "/test-msg", nil)
	reqEN.Header.Set("Accept-Language", "en-US")
	respEN, err := app.Test(reqEN)
	if err != nil {
		t.Fatalf("app.Test failed: %v", err)
	}
	bodyEN, _ := io.ReadAll(respEN.Body)
	var resEN APIResponse
	_ = json.Unmarshal(bodyEN, &resEN)
	if resEN.Message != "Registration successful" {
		t.Errorf("expected English message 'Registration successful', got %q", resEN.Message)
	}
}

func TestCreatedResponse(t *testing.T) {
	app := fiber.New()
	app.Post("/test-created", func(c *fiber.Ctx) error {
		return CreatedResponse(c, fiber.Map{"id": "new-resource-id"})
	})

	req := httptest.NewRequest(http.MethodPost, "/test-created", nil)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test failed: %v", err)
	}

	if resp.StatusCode != http.StatusCreated {
		t.Errorf("expected 201 Created, got %d", resp.StatusCode)
	}

	body, _ := io.ReadAll(resp.Body)
	var res APIResponse
	_ = json.Unmarshal(body, &res)
	if !res.Success {
		t.Errorf("expected Success to be true")
	}
}

func TestErrorResponse(t *testing.T) {
	app := fiber.New()
	app.Get("/test-error", func(c *fiber.Ctx) error {
		return ErrorResponse(c, fiber.StatusUnauthorized, "Token tidak valid atau sudah kedaluwarsa")
	})

	reqEN := httptest.NewRequest(http.MethodGet, "/test-error", nil)
	reqEN.Header.Set("Accept-Language", "en")
	resp, err := app.Test(reqEN)
	if err != nil {
		t.Fatalf("app.Test failed: %v", err)
	}

	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("expected 401 Unauthorized, got %d", resp.StatusCode)
	}

	body, _ := io.ReadAll(resp.Body)
	var res APIResponse
	_ = json.Unmarshal(body, &res)
	if res.Success {
		t.Errorf("expected Success to be false")
	}
	if res.Message != "Invalid or expired token" {
		t.Errorf("expected translated message 'Invalid or expired token', got %q", res.Message)
	}
}

func TestErrorResponse_DefaultCode(t *testing.T) {
	cases := []struct {
		status int
		code   string
	}{
		{fiber.StatusBadRequest, "ERR_BAD_REQUEST"},
		{fiber.StatusUnauthorized, "ERR_UNAUTHORIZED"},
		{fiber.StatusForbidden, "ERR_FORBIDDEN"},
		{fiber.StatusNotFound, "ERR_NOT_FOUND"},
		{fiber.StatusConflict, "ERR_CONFLICT"},
		{fiber.StatusInternalServerError, "ERR_INTERNAL"},
	}

	for _, tt := range cases {
		t.Run(tt.code, func(t *testing.T) {
			app := fiber.New()
			app.Get("/test-code", func(c *fiber.Ctx) error {
				return ErrorResponse(c, tt.status, "Pesan")
			})

			resp, err := app.Test(httptest.NewRequest(http.MethodGet, "/test-code", nil))
			if err != nil {
				t.Fatalf("app.Test failed: %v", err)
			}
			body, _ := io.ReadAll(resp.Body)
			var res APIResponse
			_ = json.Unmarshal(body, &res)
			if res.Code != tt.code {
				t.Errorf("expected code %q, got %q", tt.code, res.Code)
			}
		})
	}
}

func TestErrorResponseWithCode(t *testing.T) {
	app := fiber.New()
	app.Get("/test-code", func(c *fiber.Ctx) error {
		return ErrorResponseWithCode(c, fiber.StatusConflict, "ERR_EMAIL_TAKEN", "Email sudah terdaftar")
	})

	for _, lang := range []string{"id", "en"} {
		req := httptest.NewRequest(http.MethodGet, "/test-code", nil)
		req.Header.Set("Accept-Language", lang)
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("app.Test failed: %v", err)
		}
		body, _ := io.ReadAll(resp.Body)
		var res APIResponse
		_ = json.Unmarshal(body, &res)
		if resp.StatusCode != http.StatusConflict {
			t.Errorf("expected 409, got %d", resp.StatusCode)
		}
		if res.Code != "ERR_EMAIL_TAKEN" {
			t.Errorf("[%s] expected code ERR_EMAIL_TAKEN, got %q", lang, res.Code)
		}
		if res.Message == "" {
			t.Errorf("[%s] expected displayable message, got empty", lang)
		}
	}
}

func TestSuccessResponse_OmitsCode(t *testing.T) {
	app := fiber.New()
	app.Get("/test-ok", func(c *fiber.Ctx) error {
		return SuccessResponse(c, fiber.Map{"item": "sensor-1"})
	})

	resp, err := app.Test(httptest.NewRequest(http.MethodGet, "/test-ok", nil))
	if err != nil {
		t.Fatalf("app.Test failed: %v", err)
	}
	body, _ := io.ReadAll(resp.Body)
	if json.Valid(body) {
		var raw map[string]interface{}
		_ = json.Unmarshal(body, &raw)
		if _, present := raw["code"]; present {
			t.Errorf("expected no code field on success, got %v", raw["code"])
		}
	}
}

func TestErrorResponse_RedactsInternals(t *testing.T) {
	internals := []string{
		"record not found",
		`pq: duplicate key value violates unique constraint "users_email_key"`,
		"dial tcp 10.0.0.1:5432: connection refused",
	}
	for _, msg := range internals {
		app := fiber.New()
		app.Get("/test-redact", func(c *fiber.Ctx) error {
			return ErrorResponse(c, fiber.StatusInternalServerError, msg)
		})

		resp, err := app.Test(httptest.NewRequest(http.MethodGet, "/test-redact", nil))
		if err != nil {
			t.Fatalf("app.Test failed: %v", err)
		}
		body, _ := io.ReadAll(resp.Body)
		var res APIResponse
		_ = json.Unmarshal(body, &res)
		if res.Code != "ERR_INTERNAL" {
			t.Errorf("expected code ERR_INTERNAL, got %q", res.Code)
		}
		if res.Message == msg {
			t.Errorf("internal text leaked to client: %q", msg)
		}
	}
}

func TestErrorResponse_PreservesUserMessages(t *testing.T) {
	app := fiber.New()
	app.Get("/test-user-msg", func(c *fiber.Ctx) error {
		return ErrorResponse(c, fiber.StatusBadRequest, "NIK harus 16 digit")
	})

	resp, err := app.Test(httptest.NewRequest(http.MethodGet, "/test-user-msg", nil))
	if err != nil {
		t.Fatalf("app.Test failed: %v", err)
	}
	body, _ := io.ReadAll(resp.Body)
	var res APIResponse
	_ = json.Unmarshal(body, &res)
	if res.Message != "NIK harus 16 digit" {
		t.Errorf("user-facing message altered: %q", res.Message)
	}
}
