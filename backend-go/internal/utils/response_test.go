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
