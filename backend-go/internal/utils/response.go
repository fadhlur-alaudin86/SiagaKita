package utils

import (
	"strings"

	"siagakita-backend/internal/i18n"

	"github.com/gofiber/fiber/v2"
)

// APIResponse is the standard JSON envelope for all responses.
type APIResponse struct {
	Success bool        `json:"success"`
	Code    string      `json:"code,omitempty"`
	Message string      `json:"message,omitempty"`
	Data    interface{} `json:"data,omitempty"`
}

// internalErrorMarkers lists substrings that reveal driver or storage
// internals and must never reach clients. Messages containing them are
// replaced with a generic, translatable failure message (detail stays logged
// by callers via zerolog).
var internalErrorMarkers = []string{
	"record not found",
	"duplicate key",
	"violates unique constraint",
	"violates foreign key constraint",
	"violates check constraint",
	"pq:",
	"gorm:",
	"dial tcp",
	"connection refused",
	"SQLSTATE",
}

// sanitizeMessage replaces driver/storage-internal error text with a safe
// generic message. Intended user-facing messages pass through untouched.
func sanitizeMessage(message string) string {
	lowered := strings.ToLower(message)
	for _, marker := range internalErrorMarkers {
		if strings.Contains(lowered, marker) {
			return "Terjadi kesalahan pada server"
		}
	}
	return message
}

// defaultErrorCode maps HTTP status to a generic machine-readable code so
// every error response carries one even when no semantic code is assigned.
func defaultErrorCode(status int) string {
	switch status {
	case fiber.StatusBadRequest:
		return "ERR_BAD_REQUEST"
	case fiber.StatusUnauthorized:
		return "ERR_UNAUTHORIZED"
	case fiber.StatusForbidden:
		return "ERR_FORBIDDEN"
	case fiber.StatusNotFound:
		return "ERR_NOT_FOUND"
	case fiber.StatusConflict:
		return "ERR_CONFLICT"
	case fiber.StatusUnprocessableEntity:
		return "ERR_VALIDATION"
	case fiber.StatusTooManyRequests:
		return "ERR_RATE_LIMITED"
	case fiber.StatusInternalServerError:
		return "ERR_INTERNAL"
	default:
		return "ERR_UNKNOWN"
	}
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
// A generic machine-readable code derived from the status is always included;
// use ErrorResponseWithCode for semantic codes clients can switch on.
// Driver-internal text is redacted to a generic message before sending.
func ErrorResponse(c *fiber.Ctx, status int, message string) error {
	translated := i18n.Translate(i18n.GetLocale(c), sanitizeMessage(message))
	return c.Status(status).JSON(APIResponse{Success: false, Code: defaultErrorCode(status), Message: translated})
}

// ErrorResponseWithCode returns an error response with an explicit semantic
// code (e.g. ERR_EMAIL_TAKEN) for client branching. Message stays displayable.
func ErrorResponseWithCode(c *fiber.Ctx, status int, code, message string) error {
	translated := i18n.Translate(i18n.GetLocale(c), sanitizeMessage(message))
	return c.Status(status).JSON(APIResponse{Success: false, Code: code, Message: translated})
}
