package user

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gofiber/fiber/v2"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestUpdateFCMToken_Handler(t *testing.T) {
	app := fiber.New()
	handler := &Handler{}

	app.Put("/api/v1/users/profile/fcm-token", func(c *fiber.Ctx) error {
		// Mock unauthorized when no locals
		if c.Get("X-User-ID") != "" {
			c.Locals("userID", c.Get("X-User-ID"))
		}
		return handler.UpdateFCMToken(c)
	})

	t.Run("Unauthorized_MissingUserID", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPut, "/api/v1/users/profile/fcm-token", bytes.NewBufferString(`{"fcm_token":"abc"}`))
		req.Header.Set("Content-Type", "application/json")
		resp, err := app.Test(req)
		require.NoError(t, err)
		assert.Equal(t, fiber.StatusUnauthorized, resp.StatusCode)
	})

	t.Run("BadRequest_EmptyToken", func(t *testing.T) {
		body, _ := json.Marshal(UpdateFCMTokenRequest{FCMToken: "   "})
		req := httptest.NewRequest(http.MethodPut, "/api/v1/users/profile/fcm-token", bytes.NewBuffer(body))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-User-ID", "user-123")
		resp, err := app.Test(req)
		require.NoError(t, err)
		assert.Equal(t, fiber.StatusBadRequest, resp.StatusCode)
	})

	t.Run("BadRequest_InvalidJSON", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPut, "/api/v1/users/profile/fcm-token", bytes.NewBufferString(`{invalid json}`))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-User-ID", "user-123")
		resp, err := app.Test(req)
		require.NoError(t, err)
		assert.Equal(t, fiber.StatusBadRequest, resp.StatusCode)
	})
}

func TestClearFCMToken_Handler(t *testing.T) {
	app := fiber.New()
	handler := &Handler{}

	app.Delete("/api/v1/users/profile/fcm-token", func(c *fiber.Ctx) error {
		if c.Get("X-User-ID") != "" {
			c.Locals("userID", c.Get("X-User-ID"))
		}
		return handler.ClearFCMToken(c)
	})

	t.Run("Unauthorized_MissingUserID", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodDelete, "/api/v1/users/profile/fcm-token", nil)
		resp, err := app.Test(req)
		require.NoError(t, err)
		assert.Equal(t, fiber.StatusUnauthorized, resp.StatusCode)
	})
}
