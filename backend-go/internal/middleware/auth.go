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
			if rdb != nil {
				ctx, canceled := context.WithTimeout(context.Background(), 2*time.Second)
				defer canceled()

				// Update Redis online status TTL (90s = 3x 30s heartbeat)
				rdb.Set(ctx, "user:online:"+userID, "1", 90*time.Second)

				// Throttle DB write: hanya tulis ke DB PostgreSQL maksimal sekali setiap 60 detik per user
				throttleKey := "throttle:last_active:" + userID
				status, err := rdb.SetArgs(ctx, throttleKey, "1", redis.SetArgs{Mode: "NX", TTL: 60 * time.Second}).Result()
				if err == nil && status == "OK" {
					if err := db.Exec("UPDATE users SET last_active_at = ? WHERE id = ?", time.Now(), userID).Error; err != nil {
						utils.Error().Err(err).Str("user_id", userID).Msg("[TouchLastActive] Failed to update last_active_at in DB")
					}
				}
			} else {
				if err := db.Exec("UPDATE users SET last_active_at = ? WHERE id = ?", time.Now(), userID).Error; err != nil {
					utils.Error().Err(err).Str("user_id", userID).Msg("[TouchLastActive] Failed to update last_active_at in DB")
				}
			}
		}()
		return nil
	}
}

// Auth validates JWT from the Authorization header.
// On success, injects "userID", "userRole", and "userJTI" into c.Locals.
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
		if claims.TokenType != "" && claims.TokenType != "access" {
			return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Tipe token tidak valid")
		}
		c.Locals("userID", claims.UserID)
		c.Locals("userRole", claims.Role)
		c.Locals("userJTI", claims.JTI) // Dibutuhkan oleh SessionGuard
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

// VolunteerOnly hanya mengizinkan volunteer (relawan terverifikasi).
func VolunteerOnly() fiber.Handler {
	return RequireRoles("volunteer")
}

// BanCheck menolak request jika user memiliki status is_sos_banned = true dan belum kedaluwarsa.
// Harus digunakan SETELAH Auth middleware, dan hanya untuk endpoint SOS/Laporan.
func BanCheck(db *gorm.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		userID, _ := c.Locals("userID").(string)
		if userID == "" {
			return c.Next()
		}
		var row struct {
			IsSOSBanned bool       `gorm:"column:is_sos_banned"`
			BannedUntil *time.Time `gorm:"column:banned_until"`
		}
		db.Raw("SELECT p.is_sos_banned, p.banned_until FROM user_profiles p WHERE p.user_id = ?", userID).Scan(&row)
		if row.IsSOSBanned {
			// Jika ban sementara dan masa berlakunya sudah lewat, unban otomatis
			if row.BannedUntil != nil && time.Now().After(*row.BannedUntil) {
				_ = db.Exec("UPDATE user_profiles SET is_sos_banned = FALSE, banned_until = NULL WHERE user_id = ?", userID).Error
				return c.Next()
			}
			return utils.ErrorResponse(c, fiber.StatusForbidden, "Akun Anda saat ini diblokir dari fitur SOS. Hubungi admin.")
		}
		return c.Next()
	}
}
