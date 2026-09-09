package utils

import (
	"siagakita-backend/internal/i18n"

	"github.com/gofiber/fiber/v2"
)

// APIResponse is the standard JSON envelope for all responses.
type APIResponse struct {
	Success bool        `json:"success"`
	Message string      `json:"message,omitempty"`
	Data    interface{} `json:"data,omitempty"`
}

// SuccessResponse returns HTTP 200 with data.
// Automatically translates "message" field if data is a map.
func SuccessResponse(c *fiber.Ctx, data interface{}) error {
	if m, ok := data.(fiber.Map); ok {
		if msg, ok := m["message"].(string); ok {
			m["message"] = i18n.Translate(i18n.GetLocale(c), msg)
		}
	} else if m, ok := data.(map[string]interface{}); ok {
		if msg, ok := m["message"].(string); ok {
			m["message"] = i18n.Translate(i18n.GetLocale(c), msg)
		}
	}
	return c.Status(fiber.StatusOK).JSON(APIResponse{Success: true, Data: data})
}

// SuccessResponseWithMsg returns HTTP 200 with a localized message and data.
func SuccessResponseWithMsg(c *fiber.Ctx, message string, data interface{}) error {
	translated := i18n.Translate(i18n.GetLocale(c), message)
	return c.Status(fiber.StatusOK).JSON(APIResponse{Success: true, Message: translated, Data: data})
}

// CreatedResponse returns HTTP 201 with data.
func CreatedResponse(c *fiber.Ctx, data interface{}) error {
	return c.Status(fiber.StatusCreated).JSON(APIResponse{Success: true, Data: data})
}

// ErrorResponse returns an error response with the given HTTP status and message.
// The message is automatically localized according to the request's Accept-Language.
func ErrorResponse(c *fiber.Ctx, status int, message string) error {
	translated := i18n.Translate(i18n.GetLocale(c), message)
	return c.Status(status).JSON(APIResponse{Success: false, Message: translated})
}
