// Package middleware provides HTTP middleware for the SiagaKita API.
//
// RateLimit is a per-IP fixed-window rate limiter used to protect abuse-prone
// routes (auth login/register/OTP-request and incident writes). It is
// mutex-protected, resets each IP's window lazily, and prunes expired entries
// once the map grows beyond a configured bound so memory stays bounded.
package middleware

import (
	"sync"
	"time"

	"siagakita-backend/internal/utils"

	"github.com/gofiber/fiber/v2"
)

// windowEntry holds the fixed-window counter for a single client IP.
type windowEntry struct {
	count       int
	windowStart time.Time
}

// RateLimiter is a per-IP fixed-window counter.
//
// All methods are safe for concurrent use.
type RateLimiter struct {
	mu         sync.Mutex
	windows    map[string]*windowEntry
	limit      int
	window     time.Duration
	maxEntries int
}

// NewRateLimiter returns a RateLimiter that allows at most `limit` requests
// per `window` per client IP. `maxEntries` bounds the in-memory map; once
// exceeded, expired windows are pruned lazily.
func NewRateLimiter(limit int, window time.Duration, maxEntries int) *RateLimiter {
	return &RateLimiter{
		windows:    make(map[string]*windowEntry),
		limit:      limit,
		window:     window,
		maxEntries: maxEntries,
	}
}

// Allow reports whether the request from `ip` is within the rate limit and
// advances the counter. It performs a lazy per-IP window reset: if the IP's
// window has expired, a fresh window starts.
func (rl *RateLimiter) Allow(ip string) bool {
	if ip == "" {
		ip = "unknown"
	}

	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	entry, ok := rl.windows[ip]
	if !ok || now.After(entry.windowStart.Add(rl.window)) {
		// Lazy per-IP reset: start a fresh window with this request counted.
		rl.windows[ip] = &windowEntry{count: 1, windowStart: now}
		return true
	}

	entry.count++
	if entry.count > rl.limit {
		return false
	}

	// Bound memory: prune expired windows once the map grows beyond the cap.
	if len(rl.windows) > rl.maxEntries {
		rl.pruneLocked(now)
	}
	return true
}

// pruneLocked removes entries whose fixed window has expired. The caller must
// hold rl.mu.
func (rl *RateLimiter) pruneLocked(now time.Time) {
	for ip, entry := range rl.windows {
		if now.After(entry.windowStart.Add(rl.window)) {
			delete(rl.windows, ip)
		}
	}
}

// RateLimit returns a fiber.Handler applying the per-IP fixed-window limiter.
// The bucket key is c.IP(), not X-Forwarded-For directly. main.go enables
// EnableTrustedProxyCheck, so c.IP() honors X-Forwarded-For only when the
// direct connection comes from a listed proxy; direct clients fall back to the
// real remote address and cannot spoof their IP via X-Forwarded-For to evade
// the limit. On limit exceeded it returns 429 with code ERR_RATE_LIMITED and
// a localized message (id + en via the standard i18n table).
func RateLimit(rl *RateLimiter) fiber.Handler {
	return func(c *fiber.Ctx) error {
		if !rl.Allow(c.IP()) {
			return utils.ErrorResponse(c, fiber.StatusTooManyRequests,
				"Terlalu banyak permintaan. Coba lagi nanti.")
		}
		return c.Next()
	}
}
