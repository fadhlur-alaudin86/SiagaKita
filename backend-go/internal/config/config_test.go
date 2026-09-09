package config

import (
	"os"
	"testing"
	"time"
)

func TestLoadConfig_Defaults(t *testing.T) {
	// Clear any environment variables that might be set in the running process
	envVars := []string{
		"DB_HOST", "DB_PORT", "DB_USER", "DB_PASSWORD", "DB_NAME",
		"REDIS_HOST", "REDIS_PORT", "REDIS_PASSWORD",
		"JWT_SECRET", "JWT_ACCESS_TTL", "JWT_REFRESH_TTL",
		"SMS_GATEWAY_SECRET", "FONNTE_TOKEN", "EMAIL_FROM",
		"GMAIL_CLIENT_ID", "GMAIL_CLIENT_SECRET", "GMAIL_REFRESH_TOKEN",
		"HTTP_PORT", "WS_PORT", "SUPERADMIN_EMAIL", "SUPERADMIN_PASS",
		"UPLOAD_DIR", "UPLOAD_BASE_URL",
	}
	for _, k := range envVars {
		t.Setenv(k, "")
	}

	cfg := Load()
	if cfg == nil {
		t.Fatal("expected non-nil Config")
	}

	if cfg.DBHost != "localhost" {
		t.Errorf("expected default DBHost 'localhost', got %q", cfg.DBHost)
	}
	if cfg.DBPort != "5432" {
		t.Errorf("expected default DBPort '5432', got %q", cfg.DBPort)
	}
	if cfg.RedisHost != "localhost" {
		t.Errorf("expected default RedisHost 'localhost', got %q", cfg.RedisHost)
	}
	if cfg.RedisPort != "6379" {
		t.Errorf("expected default RedisPort '6379', got %q", cfg.RedisPort)
	}
	if cfg.HTTPPort != "8080" {
		t.Errorf("expected default HTTPPort '8080', got %q", cfg.HTTPPort)
	}
	if cfg.WSPort != "8081" {
		t.Errorf("expected default WSPort '8081', got %q", cfg.WSPort)
	}
	if cfg.JWTAccessTTL != 15*time.Minute {
		t.Errorf("expected default JWTAccessTTL 15m, got %v", cfg.JWTAccessTTL)
	}
	if cfg.JWTRefreshTTL != 168*time.Hour {
		t.Errorf("expected default JWTRefreshTTL 168h, got %v", cfg.JWTRefreshTTL)
	}
	if cfg.UploadDir != "/app/uploads" {
		t.Errorf("expected default UploadDir '/app/uploads', got %q", cfg.UploadDir)
	}
	if cfg.UploadBaseURL != "http://localhost:8080/uploads" {
		t.Errorf("expected default UploadBaseURL 'http://localhost:8080/uploads', got %q", cfg.UploadBaseURL)
	}
}

func TestLoadConfig_CustomEnv(t *testing.T) {
	t.Setenv("DB_HOST", "postgres.production.internal")
	t.Setenv("DB_PORT", "5433")
	t.Setenv("DB_USER", "siagakita_user")
	t.Setenv("DB_PASSWORD", "supersecret123")
	t.Setenv("DB_NAME", "siagakita_db")
	t.Setenv("REDIS_HOST", "redis.internal")
	t.Setenv("REDIS_PORT", "6380")
	t.Setenv("JWT_SECRET", "production-jwt-secret-xyz")
	t.Setenv("JWT_ACCESS_TTL", "30m")
	t.Setenv("JWT_REFRESH_TTL", "72h")
	t.Setenv("HTTP_PORT", "9000")
	t.Setenv("WS_PORT", "9001")
	t.Setenv("UPLOAD_DIR", "/var/data/uploads")
	t.Setenv("UPLOAD_BASE_URL", "https://api.siagakita.id/uploads")

	cfg := Load()
	if cfg == nil {
		t.Fatal("expected non-nil Config")
	}

	if cfg.DBHost != "postgres.production.internal" {
		t.Errorf("expected custom DBHost, got %q", cfg.DBHost)
	}
	if cfg.DBPort != "5433" {
		t.Errorf("expected custom DBPort, got %q", cfg.DBPort)
	}
	if cfg.DBUser != "siagakita_user" {
		t.Errorf("expected custom DBUser, got %q", cfg.DBUser)
	}
	if cfg.DBPassword != "supersecret123" {
		t.Errorf("expected custom DBPassword, got %q", cfg.DBPassword)
	}
	if cfg.DBName != "siagakita_db" {
		t.Errorf("expected custom DBName, got %q", cfg.DBName)
	}
	if cfg.RedisHost != "redis.internal" {
		t.Errorf("expected custom RedisHost, got %q", cfg.RedisHost)
	}
	if cfg.RedisPort != "6380" {
		t.Errorf("expected custom RedisPort, got %q", cfg.RedisPort)
	}
	if cfg.JWTSecret != "production-jwt-secret-xyz" {
		t.Errorf("expected custom JWTSecret, got %q", cfg.JWTSecret)
	}
	if cfg.JWTAccessTTL != 30*time.Minute {
		t.Errorf("expected custom JWTAccessTTL 30m, got %v", cfg.JWTAccessTTL)
	}
	if cfg.JWTRefreshTTL != 72*time.Hour {
		t.Errorf("expected custom JWTRefreshTTL 72h, got %v", cfg.JWTRefreshTTL)
	}
	if cfg.HTTPPort != "9000" {
		t.Errorf("expected custom HTTPPort '9000', got %q", cfg.HTTPPort)
	}
	if cfg.WSPort != "9001" {
		t.Errorf("expected custom WSPort '9001', got %q", cfg.WSPort)
	}
	if cfg.UploadDir != "/var/data/uploads" {
		t.Errorf("expected custom UploadDir, got %q", cfg.UploadDir)
	}
	if cfg.UploadBaseURL != "https://api.siagakita.id/uploads" {
		t.Errorf("expected custom UploadBaseURL, got %q", cfg.UploadBaseURL)
	}
}

func TestLoadConfig_InvalidDurationFallback(t *testing.T) {
	t.Setenv("JWT_ACCESS_TTL", "invalid-duration-value")
	t.Setenv("JWT_REFRESH_TTL", "not-a-valid-duration")

	cfg := Load()
	if cfg == nil {
		t.Fatal("expected non-nil Config")
	}

	if cfg.JWTAccessTTL != 15*time.Minute {
		t.Errorf("expected fallback JWTAccessTTL 15m, got %v", cfg.JWTAccessTTL)
	}
	if cfg.JWTRefreshTTL != 168*time.Hour {
		t.Errorf("expected fallback JWTRefreshTTL 168h, got %v", cfg.JWTRefreshTTL)
	}
}

func TestGetEnv(t *testing.T) {
	key := "TEST_ENV_KEY_TEMPORARY"
	val := "custom_val"
	fallback := "fallback_val"

	_ = os.Unsetenv(key)
	if res := getEnv(key, fallback); res != fallback {
		t.Errorf("expected %q, got %q", fallback, res)
	}

	t.Setenv(key, val)
	if res := getEnv(key, fallback); res != val {
		t.Errorf("expected %q, got %q", val, res)
	}
}
