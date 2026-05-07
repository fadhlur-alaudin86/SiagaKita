package middleware

import (
	"siagakita-backend/internal/config"
	"siagakita-backend/internal/utils"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
)

// TouchLastActive memperbarui kolom last_active_at di tabel users setiap kali
// user civilian/volunteer melakukan request API. Digunakan untuk menampilkan
// status "Online / Berjalan di latar belakang / Terakhir terlihat" di Console Admin.
func TouchLastActive(db *gorm.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		if err := c.Next(); err != nil {
			return err
		}
		role, _ := c.Locals("userRole").(string)
		if role != "civilian" && role != "volunteer" {
			return nil
		}
		userID, _ := c.Locals("userID").(string)
		if userID == "" {
			return nil
		}
		// Fire-and-forget, jangan blokir response
		go func() {
			db.Exec("UPDATE users SET last_active_at = ? WHERE id = ?", time.Now(), userID)
		}()
		return nil
	}
}


// Auth validates JWT from the Authorization header.
// On success, injects "userID" and "userRole" into c.Locals.
func Auth(cfg *config.Config) fiber.Handler {
	return func(c *fiber.Ctx) error {
		authHeader := c.Get("Authorization")
		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Authorization header missing atau tidak valid")
		}
		tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
		claims, err := utils.ParseToken(tokenStr, cfg.JWTSecret)
		if err != nil {
			return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Token tidak valid atau sudah kedaluwarsa")
		}
		c.Locals("userID", claims.UserID)
		c.Locals("userRole", claims.Role)
		return c.Next()
	}
}

// APIKeyGateway validates a static API key header (SMS fallback endpoint).
func APIKeyGateway(cfg *config.Config) fiber.Handler {
	return func(c *fiber.Ctx) error {
		key := c.Get("X-Gateway-Secret")
		if key == "" || key != cfg.SMSGatewaySecret {
			return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Gateway secret tidak valid")
		}
		return c.Next()
	}
}

// ─── RBAC Middleware ──────────────────────────────────────────────────────────

// RequireRoles returns a middleware that only allows the specified roles.
// Must be used after Auth middleware.
//
// Usage:
//
//	app.Get("/admin/...", authMw, middleware.RequireRoles("admin","superadmin"), handler)
func RequireRoles(roles ...string) fiber.Handler {
	allowed := make(map[string]bool, len(roles))
	for _, r := range roles {
		allowed[r] = true
	}
	return func(c *fiber.Ctx) error {
		role, ok := c.Locals("userRole").(string)
		if !ok || !allowed[role] {
			return utils.ErrorResponse(c, fiber.StatusForbidden, "Akses ditolak: izin tidak mencukupi")
		}
		return c.Next()
	}
}

// SuperAdminOnly adalah shorthand untuk RequireRoles("superadmin").
func SuperAdminOnly() fiber.Handler {
	return RequireRoles("superadmin")
}

// AdminOnly mengizinkan admin dan superadmin.
func AdminOnly() fiber.Handler {
	return RequireRoles("admin", "superadmin")
}

// ConsoleOnly mengizinkan semua role console (superadmin, admin, agency).
func ConsoleOnly() fiber.Handler {
	return RequireRoles("superadmin", "admin", "agency")
}

// AgencyOnly mengizinkan agency dan admin (admin bisa lihat data instansi).
func AgencyOnly() fiber.Handler {
	return RequireRoles("agency", "admin", "superadmin")
}

// PersonnelOnly hanya mengizinkan agency_personnel.
func PersonnelOnly() fiber.Handler {
	return RequireRoles("agency_personnel")
}

// CitizenVolunteer hanya mengizinkan civilian dan volunteer (mobile app utama).
func CitizenVolunteer() fiber.Handler {
	return RequireRoles("civilian", "volunteer")
}
