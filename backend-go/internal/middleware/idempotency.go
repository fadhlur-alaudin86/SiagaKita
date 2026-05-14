package middleware

import (
	"context"
	"encoding/json"
	"time"

	"siagakita-backend/internal/utils"

	"github.com/gofiber/fiber/v2"
	"github.com/redis/go-redis/v9"
)

// IdempotencyTTL adalah berapa lama hasil aksi disimpan di Redis.
// Jika request yang sama datang dalam window ini, kembalikan cached response.
const IdempotencyTTL = 60 * time.Second

// idempotencyResponse adalah struktur yang disimpan di Redis.
type idempotencyResponse struct {
	StatusCode int             `json:"status_code"`
	Body       json.RawMessage `json:"body"`
}

// Idempotency middleware mencegah duplikasi aksi kritis dari console.
//
// Cara kerja:
//  1. Baca header X-Idempotency-Key dari request
//  2. Cek di Redis — jika sudah ada, kembalikan cached response langsung
//  3. Jika belum ada, proses request normal, simpan response ke Redis
//
// Hanya aktif untuk metode yang mengubah state (POST, PUT, PATCH, DELETE).
// GET request dilewati.
func Idempotency(rdb *redis.Client) fiber.Handler {
	return func(c *fiber.Ctx) error {
		// Skip GET dan OPTIONS
		method := c.Method()
		if method == fiber.MethodGet || method == fiber.MethodOptions || method == fiber.MethodHead {
			return c.Next()
		}

		key := c.Get("X-Idempotency-Key")
		if key == "" {
			// Tidak ada key → lewati (tidak wajib untuk semua endpoint)
			return c.Next()
		}

		redisKey := "idempotency:" + key
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()

		// Cek apakah sudah pernah diproses
		cached, err := rdb.Get(ctx, redisKey).Bytes()
		if err == nil {
			// Sudah pernah diproses — kembalikan cached response
			var resp idempotencyResponse
			if jsonErr := json.Unmarshal(cached, &resp); jsonErr == nil {
				utils.Info().Str("key", key).Msg("[Idempotency] Cache hit — returning cached response")
				c.Set("X-Idempotency-Cached", "true")
				return c.Status(resp.StatusCode).Send(resp.Body)
			}
		}

		// Belum pernah diproses — jalankan handler
		if err := c.Next(); err != nil {
			return err
		}

		// Simpan response ke Redis
		respBody := c.Response().Body()
		toCache, _ := json.Marshal(idempotencyResponse{
			StatusCode: c.Response().StatusCode(),
			Body:       json.RawMessage(respBody),
		})

		ctx2, cancel2 := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel2()
		_ = rdb.Set(ctx2, redisKey, toCache, IdempotencyTTL)

		return nil
	}
}
