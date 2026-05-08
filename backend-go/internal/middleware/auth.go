package middleware

import (
	"context"
	"strings"
	"time"

	"siagakita-backend/internal/config"
	"siagakita-backend/internal/utils"

	"github.com/gofiber/fiber/v2"
	"github.com/redis/go-redis/v9"
	"gorm.io/gorm"
)

// TouchLastActive memperbarui kolom last_active_at di tabel users setiap kali
// user civilian/volunteer melakukan request API. Digunakan untuk menampilkan
// status "Online / Berjalan di latar belakang / Terakhir terlihat" di Console Admin.
func TouchLastActive(db *gorm.DB, rdb *redis.Client) fiber.Handler {
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
			// Update DB timestamp
			db.Exec("UPDATE users SET last_active_at = ? WHERE id = ?", time.Now(), userID)
			
			// Update Redis online status TTL (90s = 3x 30s heartbeat)
			if rdb != nil {
				ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
				defer cancel()
				rdb.Set(ctx, "user:online:"+userID, "1", 90*time.Second)
			}
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

// BanCheck menolak request jika user memiliki status is_sos_banned = true.
// Harus digunakan SETELAH Auth middleware, dan hanya untuk endpoint SOS/Laporan.
func BanCheck(db *gorm.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		userID, _ := c.Locals("userID").(string)
		if userID == "" {
			return c.Next()
		}
		var isBanned bool
		db.Raw("SELECT p.is_sos_banned FROM user_profiles p WHERE p.user_id = ?", userID).Scan(&isBanned)
		if isBanned {
			return utils.ErrorResponse(c, fiber.StatusForbidden, "Akun Anda saat ini diblokir dari fitur SOS. Hubungi admin.")
		}
		return c.Next()
	}
}
