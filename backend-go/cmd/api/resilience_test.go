// Purpose: Slow/hung client resilience tests (reliability criterion C5):
// proves the production fiber config tolerates dribbling, abandoned, and
// oversized clients without hanging, leaking goroutines, or losing Rule B
// error envelopes, and stays healthy afterwards.
// Data & Logic Flow: A minimal app is built with the unexported
// newFiberConfig() (production-equivalent timeouts) and served on a real
// 127.0.0.1 listener so kernel-level read deadlines actually apply; raw TCP
// clients dribble or abandon requests while goroutine counts are sampled.
// Key Components: TestSlowRequestBodyClosedByReadTimeout,
// TestAbandonedConnectionsKeepServerHealthy,
// TestGoroutineCountBoundedUnderChurn, TestBodyLimitRejected,
// TestRuleBErrorEnvelopePresent.

package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http/httptest"
	"runtime"
	"testing"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"siagakita-backend/internal/config"
	"siagakita-backend/internal/middleware"
)

const resilienceJWTSecret = "resilience-test-secret"

// newResilienceApp builds a minimal app using the production fiber config and
// the middleware stack shape relevant to resilience (auth + Rule B errors).
func newResilienceApp() *fiber.App {
	app := fiber.New(newFiberConfig())

	app.Post("/echo", func(c *fiber.Ctx) error {
		body := c.Body()
		return c.Status(fiber.StatusOK).SendString(fmt.Sprintf("len=%d", len(body)))
	})

	// Liveness probe used by resilience tests after abusive-client scenarios.
	app.Get("/echo", func(c *fiber.Ctx) error {
		return c.SendString("ok")
	})

	cfg := &config.Config{
		JWTSecret:     resilienceJWTSecret,
		JWTAccessTTL:  time.Minute,
		JWTRefreshTTL: time.Hour,
	}
	app.Get("/protected", middleware.Auth(cfg), func(c *fiber.Ctx) error {
		return c.SendString("ok")
	})

	return app
}

// startRealListener serves the app on a random loopback port so that fiber's
// ReadTimeout/WriteTimeout apply to genuine TCP connections. Returns the
// address string; closing the listener is wired to t.Cleanup.
func startRealListener(t *testing.T, app *fiber.App) string {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	require.NoError(t, err)
	t.Cleanup(func() { _ = ln.Close() })
	go func() {
		_ = app.Listener(ln)
	}()
	return ln.Addr().String()
}

// requestOverTCP sends a raw HTTP request, reads the full response, and
// returns the status line. Fails the test on transport errors.
func requestOverTCP(t *testing.T, addr, rawRequest string) string {
	t.Helper()
	conn, err := net.DialTimeout("tcp", addr, 2*time.Second)
	require.NoError(t, err)
	defer conn.Close()
	require.NoError(t, conn.SetDeadline(time.Now().Add(10*time.Second)))

	_, err = conn.Write([]byte(rawRequest))
	require.NoError(t, err)
	resp, err := io.ReadAll(conn)
	require.NoError(t, err)
	return string(resp)
}

func TestSlowRequestBodyClosedByReadTimeout(t *testing.T) {
	app := newResilienceApp()
	addr := startRealListener(t, app)

	conn, err := net.DialTimeout("tcp", addr, 2*time.Second)
	require.NoError(t, err)
	defer conn.Close()

	// Announce a 1 MB body but dribble it one byte at a time, never finishing:
	// fiber's ReadTimeout (15s, set at connection start) must close the socket.
	header := "POST /echo HTTP/1.1\r\n" +
		fmt.Sprintf("Host: %s\r\n", addr) +
		"Content-Type: text/plain\r\n" +
		"Content-Length: 1048576\r\n\r\n"
	_, err = conn.Write([]byte(header))
	require.NoError(t, err)

	closed := make(chan error, 1)
	go func() {
		for {
			if _, err := conn.Write([]byte{0x41}); err != nil {
				closed <- err
				return
			}
			time.Sleep(100 * time.Millisecond)
			// Detect server-side close: a short read with EOF.
			if err := conn.SetReadDeadline(time.Now().Add(50 * time.Millisecond)); err != nil {
				closed <- err
				return
			}
			one := make([]byte, 1)
			if _, err := conn.Read(one); err != nil && err.Error() == "EOF" {
				closed <- err
				return
			}
		}
	}()

	select {
	case <-closed:
		// Server closed the dribbling connection: ReadTimeout enforced.
	case <-time.After(20 * time.Second):
		t.Fatal("server kept a body-dribbling connection alive past ReadTimeout (15s) + slack")
	}

	// Server must remain healthy afterwards.
	resp := requestOverTCP(t, addr,
		"GET /echo HTTP/1.1\r\n"+
			fmt.Sprintf("Host: %s\r\n", addr)+
			"Connection: close\r\n\r\n")
	assert.Contains(t, resp, "200", "server must stay healthy after closing a slow client")
}

func TestAbandonedConnectionsKeepServerHealthy(t *testing.T) {
	app := newResilienceApp()
	addr := startRealListener(t, app)

	// Clients that connect, send a full request, and vanish before reading the
	// response must not wedge the server.
	for i := 0; i < 20; i++ {
		conn, err := net.DialTimeout("tcp", addr, 2*time.Second)
		require.NoError(t, err)
		raw := "POST /echo HTTP/1.1\r\n" +
			fmt.Sprintf("Host: %s\r\n", addr) +
			"Content-Type: text/plain\r\n" +
			fmt.Sprintf("Content-Length: %d\r\n\r\n", i) +
			string(make([]byte, i))
		_, _ = conn.Write([]byte(raw))
		_ = conn.Close() // abandon: no response read
	}

	time.Sleep(500 * time.Millisecond)

	resp := requestOverTCP(t, addr,
		"GET /echo HTTP/1.1\r\n"+
			fmt.Sprintf("Host: %s\r\n", addr)+
			"Connection: close\r\n\r\n")
	assert.Contains(t, resp, "200", "server must stay healthy after abandoned connections")
}

func TestGoroutineCountBoundedUnderChurn(t *testing.T) {
	app := newResilienceApp()
	addr := startRealListener(t, app)

	runtime.GC()
	time.Sleep(200 * time.Millisecond)
	baseline := runtime.NumGoroutine()

	for i := 0; i < 60; i++ {
		conn, err := net.DialTimeout("tcp", addr, 2*time.Second)
		require.NoError(t, err)
		raw := "POST /echo HTTP/1.1\r\n" +
			fmt.Sprintf("Host: %s\r\n", addr) +
			"Content-Length: 4\r\n\r\nabcd"
		_, _ = conn.Write([]byte(raw))
		_ = conn.Close()
	}

	// Give the server time to reap handlers and closed connections.
	time.Sleep(3 * time.Second)
	runtime.GC()

	after := runtime.NumGoroutine()
	assert.LessOrEqual(t, after, baseline+30,
		"goroutine count must return near baseline after connection churn (baseline=%d after=%d)",
		baseline, after)
}

func TestBodyLimitRejected(t *testing.T) {
	app := newResilienceApp()

	// 15 MB BodyLimit: a 16 MB body must be rejected with 413, not buffered.
	oversized := make([]byte, 16*1024*1024)
	req := httptest.NewRequest(fiber.MethodPost, "/echo", bytes.NewReader(oversized))
	req.Header.Set(fiber.HeaderContentType, fiber.MIMEApplicationJSON)
	req.ContentLength = int64(len(oversized))

	resp, err := app.Test(req, -1)
	if err != nil {
		// app.Test surfaces the BodyLimit rejection as an error instead of a
		// 413 response (in real serving this becomes 413); assert the guard
		// fired either way.
		assert.Contains(t, err.Error(), "body size exceeds",
			"oversized body must hit the 15MB BodyLimit")
		return
	}
	defer resp.Body.Close()

	assert.Equal(t, fiber.StatusRequestEntityTooLarge, resp.StatusCode,
		"oversized body must hit the 15MB BodyLimit with 413")
}

func TestRuleBErrorEnvelopePresent(t *testing.T) {
	app := newResilienceApp()

	// Unauthenticated request against a protected route: the response must
	// carry a machine-readable `code` so clients can switch on it (Rule B).
	req := httptest.NewRequest(fiber.MethodGet, "/protected", nil)
	resp, err := app.Test(req)
	require.NoError(t, err)
	defer resp.Body.Close()

	require.Equal(t, fiber.StatusUnauthorized, resp.StatusCode)

	var envelope struct {
		Success bool   `json:"success"`
		Code    string `json:"code"`
		Message string `json:"message"`
	}
	require.NoError(t, json.NewDecoder(resp.Body).Decode(&envelope))
	assert.False(t, envelope.Success)
	assert.Equal(t, "ERR_UNAUTHORIZED", envelope.Code,
		"Rule B: error responses must include a machine-readable code")
	assert.NotEmpty(t, envelope.Message)
}
