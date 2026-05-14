package middleware

import (
	"context"
	"time"

	"siagakita-backend/internal/utils"

	"github.com/gofiber/fiber/v2"
	"github.com/redis/go-redis/v9"
)

// SessionGuard memvalidasi sesi aktif untuk role civilian dan volunteer.
//
// Setiap login menyimpan JTI token di Redis (key: session:{userID}).
// Jika JTI dari token yang masuk tidak cocok dengan yang tersimpan,
// berarti user sudah login di perangkat lain → tolak request dengan 401.
//
// Console roles (agency/admin/superadmin) DILEWATI — boleh multi-device.
// Harus dipasang SETELAH middleware Auth.
func SessionGuard(rdb *redis.Client) fiber.Handler {
	return func(c *fiber.Ctx) error {
		role, _ := c.Locals("userRole").(string)

		// Console roles bebas multi-device — lewati pemeriksaan sesi
		if role != "civilian" && role != "volunteer" {
			return c.Next()
		}

		userID, _ := c.Locals("userID").(string)
		jti, _ := c.Locals("userJTI").(string)
		if userID == "" || jti == "" {
			return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Token tidak valid")
		}

		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()

		stored, err := rdb.Get(ctx, "session:"+userID).Result()
		if err != nil || stored != jti {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"status":  "error",
				"code":    "SESSION_REPLACED",
				"message": "Akun ini sedang digunakan di perangkat lain. Silakan login ulang.",
			})
		}

		return c.Next()
	}
}
