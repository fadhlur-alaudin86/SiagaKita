// Purpose: Rate limiter tests for the per-IP fixed-window middleware (F6).
// Data & Logic Flow: A minimal Fiber app mounts RateLimit on a route. The
// bucket key is c.IP(), not X-Forwarded-For, because main.go enables
// EnableTrustedProxyCheck: direct clients cannot spoof their IP via
// X-Forwarded-For to get a fresh bucket. Tests assert that exceeding the limit
// within one window yields 429 + ERR_RATE_LIMITED, that spoofed
// X-Forwarded-For values from the same RemoteAddr share one bucket (anti-spoof),
// and that an expired window resets lazily. Direct unit tests on RateLimiter
// cover distinct-IP independence since httptest always reports 0.0.0.0 as the
// remote address.
// Key Components: TestRateLimit_ExceedsLimitReturns429,
// TestRateLimit_SpoofedXFFSharesBucket, TestRateLimit_WindowResetsAfterExpiry,
// TestRateLimiterAllow_DistinctIPsIndependent,
// TestRateLimiterAllow_EmptyIPFallsBackToUnknown.

package middleware

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestRateLimit_ExceedsLimitReturns429(t *testing.T) {
	rl := NewRateLimiter(3, time.Minute, 100)
	app := fiber.New()
	app.Get("/limited", RateLimit(rl), func(c *fiber.Ctx) error {
		return c.SendString("ok")
	})

	// All requests share the same remote address (0.0.0.0 via httptest), so
	// they hit one bucket.
	request := func() *http.Response {
		req := httptest.NewRequest(http.MethodGet, "/limited", nil)
		resp, err := app.Test(req)
		require.NoError(t, err)
		return resp
	}

	// First `limit` requests are allowed.
	for i := 0; i < 3; i++ {
		resp := request()
		assert.Equal(t, http.StatusOK, resp.StatusCode, "request %d should be allowed", i)
		resp.Body.Close()
	}

	// The next request exceeds the limit: 429 + ERR_RATE_LIMITED.
	resp := request()
	defer resp.Body.Close()
	assert.Equal(t, http.StatusTooManyRequests, resp.StatusCode)

	var envelope struct {
		Success bool   `json:"success"`
		Code    string `json:"code"`
		Message string `json:"message"`
	}
	require.NoError(t, json.NewDecoder(resp.Body).Decode(&envelope))
	assert.False(t, envelope.Success)
	assert.Equal(t, "ERR_RATE_LIMITED", envelope.Code, "Rule B: rate-limit responses must carry a machine-readable code")
	assert.NotEmpty(t, envelope.Message)
}

func TestRateLimit_SpoofedXFFSharesBucket(t *testing.T) {
	// Anti-spoof: X-Forwarded-For is client-controlled and must NOT create a
	// fresh bucket. Two requests with different spoofed X-Forwarded-For values
	// from the same RemoteAddr share one bucket (keyed on c.IP() = remote
	// address).
	rl := NewRateLimiter(1, time.Minute, 100)
	app := fiber.New()
	app.Get("/limited", RateLimit(rl), func(c *fiber.Ctx) error {
		return c.SendString("ok")
	})

	request := func(xff string) *http.Response {
		req := httptest.NewRequest(http.MethodGet, "/limited", nil)
		req.Header.Set("X-Forwarded-For", xff)
		resp, err := app.Test(req)
		require.NoError(t, err)
		return resp
	}

	// First request (spoofed XFF 1.1.1.1) consumes the single allowance.
	resp := request("1.1.1.1")
	assert.Equal(t, http.StatusOK, resp.StatusCode, "first request should be allowed")
	resp.Body.Close()

	// Second request with a different spoofed XFF from the same RemoteAddr must
	// still be limited: it shares the same bucket.
	resp = request("2.2.2.2")
	assert.Equal(t, http.StatusTooManyRequests, resp.StatusCode,
		"spoofed X-Forwarded-For must not grant a fresh bucket")
	resp.Body.Close()
}

func TestRateLimit_WindowResetsAfterExpiry(t *testing.T) {
	rl := NewRateLimiter(1, 50*time.Millisecond, 100)
	app := fiber.New()
	app.Get("/limited", RateLimit(rl), func(c *fiber.Ctx) error {
		return c.SendString("ok")
	})

	request := func() *http.Response {
		req := httptest.NewRequest(http.MethodGet, "/limited", nil)
		resp, err := app.Test(req)
		require.NoError(t, err)
		return resp
	}

	resp := request()
	assert.Equal(t, http.StatusOK, resp.StatusCode)
	resp.Body.Close()

	// Immediate retry: within the same (tiny) window → limited.
	resp = request()
	assert.Equal(t, http.StatusTooManyRequests, resp.StatusCode)
	resp.Body.Close()

	// Wait for the window to expire, then the lazy reset allows a new request.
	time.Sleep(100 * time.Millisecond)
	resp = request()
	assert.Equal(t, http.StatusOK, resp.StatusCode, "expired window must reset lazily")
	resp.Body.Close()
}

// Direct unit tests on the limiter (distinct IP buckets are not observable
// through httptest, which always reports 0.0.0.0 as the remote address).

func TestRateLimiterAllow_DistinctIPsIndependent(t *testing.T) {
	rl := NewRateLimiter(1, time.Minute, 100)

	assert.True(t, rl.Allow("10.0.0.1"))
	assert.False(t, rl.Allow("10.0.0.1"), "same IP must be limited within the window")
	assert.True(t, rl.Allow("10.0.0.2"), "distinct IP must have its own bucket")
	assert.False(t, rl.Allow("10.0.0.2"))
}

func TestRateLimiterAllow_EmptyIPFallsBackToUnknown(t *testing.T) {
	rl := NewRateLimiter(1, time.Minute, 100)

	assert.True(t, rl.Allow(""))
	assert.False(t, rl.Allow(""), "empty IP must fall back to a single shared bucket")
}
