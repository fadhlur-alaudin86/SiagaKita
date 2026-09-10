package ws

import (
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"siagakita-backend/internal/config"
	"siagakita-backend/internal/hub"
)

func TestNewServer_Timeouts(t *testing.T) {
	cfg := &config.Config{
		WSPort: "8081",
	}
	h := hub.New()

	srv := &http.Server{
		Addr:              ":" + cfg.WSPort,
		ReadHeaderTimeout: 10 * time.Second,
		IdleTimeout:       120 * time.Second,
	}
	_ = h

	if srv.ReadHeaderTimeout != 10*time.Second {
		t.Fatalf("expected ReadHeaderTimeout 10s, got %v", srv.ReadHeaderTimeout)
	}
	if srv.IdleTimeout != 120*time.Second {
		t.Fatalf("expected IdleTimeout 120s, got %v", srv.IdleTimeout)
	}
	if srv.Addr != ":8081" {
		t.Fatalf("expected Addr :8081, got %s", srv.Addr)
	}
}

func TestCheckOrigin(t *testing.T) {
	origEnv := os.Getenv("GO_ENV")
	origCors := os.Getenv("CORS_ALLOWED_ORIGINS")
	defer func() {
		_ = os.Setenv("GO_ENV", origEnv)
		_ = os.Setenv("CORS_ALLOWED_ORIGINS", origCors)
	}()

	// 1. Non-browser client: empty origin should always be allowed
	t.Run("EmptyOrigin_Allowed", func(t *testing.T) {
		_ = os.Setenv("GO_ENV", "production")
		req := httptest.NewRequest(http.MethodGet, "/v1/ws/connect", nil)
		if !upgrader.CheckOrigin(req) {
			t.Fatal("expected empty origin to be allowed for native clients")
		}
	})

	// 2. Development mode: any origin allowed
	t.Run("DevelopmentMode_AnyOriginAllowed", func(t *testing.T) {
		_ = os.Setenv("GO_ENV", "development")
		req := httptest.NewRequest(http.MethodGet, "/v1/ws/connect", nil)
		req.Header.Set("Origin", "http://localhost:3000")
		if !upgrader.CheckOrigin(req) {
			t.Fatal("expected arbitrary origin to be allowed in development mode")
		}
	})

	// 3. Production mode: allowed origin in CORS_ALLOWED_ORIGINS
	t.Run("ProductionMode_AllowedOrigin", func(t *testing.T) {
		_ = os.Setenv("GO_ENV", "production")
		_ = os.Setenv("CORS_ALLOWED_ORIGINS", "https://siagakita.com,https://console.siagakita.com")

		req := httptest.NewRequest(http.MethodGet, "/v1/ws/connect", nil)
		req.Header.Set("Origin", "https://console.siagakita.com")
		if !upgrader.CheckOrigin(req) {
			t.Fatal("expected allowed origin to pass in production")
		}
	})

	// 4. Production mode: disallowed origin rejected
	t.Run("ProductionMode_DisallowedOrigin", func(t *testing.T) {
		_ = os.Setenv("GO_ENV", "production")
		_ = os.Setenv("CORS_ALLOWED_ORIGINS", "https://siagakita.com")

		req := httptest.NewRequest(http.MethodGet, "/v1/ws/connect", nil)
		req.Header.Set("Origin", "https://attacker-site.com")
		if upgrader.CheckOrigin(req) {
			t.Fatal("expected unauthorized origin to be rejected in production")
		}
	})

	// 5. Production mode: default fallback allowed origins
	t.Run("ProductionMode_DefaultFallbackAllowedOrigins", func(t *testing.T) {
		_ = os.Setenv("GO_ENV", "production")
		_ = os.Unsetenv("CORS_ALLOWED_ORIGINS")

		req := httptest.NewRequest(http.MethodGet, "/v1/ws/connect", nil)
		req.Header.Set("Origin", "https://admin.siagakita.com")
		if !upgrader.CheckOrigin(req) {
			t.Fatal("expected default admin origin to be allowed in production fallback")
		}

		reqBad := httptest.NewRequest(http.MethodGet, "/v1/ws/connect", nil)
		reqBad.Header.Set("Origin", "https://malicious.org")
		if upgrader.CheckOrigin(reqBad) {
			t.Fatal("expected malicious origin to be rejected in production fallback")
		}
	})
}
