package config

import (
	"os"
	"time"
)

// Config holds all application configuration loaded from environment variables.
type Config struct {
	// PostgreSQL
	DBHost     string
	DBPort     string
	DBUser     string
	DBPassword string
	DBName     string

	// Redis
	RedisHost     string
	RedisPort     string
	RedisPassword string

	// JWT
	JWTSecret     string
	JWTAccessTTL  time.Duration
	JWTRefreshTTL time.Duration

	// SMS Gateway
	SMSGatewaySecret string

	// WhatsApp Gateway (Fonnte)
	FonnteToken string

	// Email Gateway (SMTP — fallback jika RESEND_API_KEY tidak diset)
	SMTPHost     string
	SMTPPort     string
	SMTPUsername string
	SMTPPassword string
	SMTPFrom     string

	// Email Gateway (Resend HTTP API — diutamakan jika RESEND_API_KEY diset)
	// Tidak butuh port SMTP, menggunakan HTTPS port 443.
	// Daftar gratis di https://resend.com
	ResendAPIKey string

	// Server
	HTTPPort string
	WSPort   string

	// Superadmin seeding
	SuperAdminEmail string
	SuperAdminPass  string
}

// Load reads environment variables and returns a populated Config.
func Load() *Config {
	accessTTL, err := time.ParseDuration(getEnv("JWT_ACCESS_TTL", "15m"))
	if err != nil {
		accessTTL = 15 * time.Minute
	}

	refreshTTL, err := time.ParseDuration(getEnv("JWT_REFRESH_TTL", "168h"))
	if err != nil {
		refreshTTL = 168 * time.Hour
	}

	return &Config{
		DBHost:           getEnv("DB_HOST", "localhost"),
		DBPort:           getEnv("DB_PORT", "5432"),
		DBUser:           getEnv("DB_USER", ""),
		DBPassword:       getEnv("DB_PASSWORD", ""),
		DBName:           getEnv("DB_NAME", ""),
		RedisHost:        getEnv("REDIS_HOST", "localhost"),
		RedisPort:        getEnv("REDIS_PORT", "6379"),
		RedisPassword:    getEnv("REDIS_PASSWORD", ""),
		JWTSecret:        getEnv("JWT_SECRET", ""),
		JWTAccessTTL:     accessTTL,
		JWTRefreshTTL:    refreshTTL,
		SMSGatewaySecret: getEnv("SMS_GATEWAY_SECRET", ""),
		FonnteToken:      getEnv("FONNTE_TOKEN", ""),
		SMTPHost:         getEnv("SMTP_HOST", "smtp.gmail.com"),
		SMTPPort:         getEnv("SMTP_PORT", "587"),
		SMTPUsername:     getEnv("SMTP_USERNAME", ""),
		SMTPPassword:     getEnv("SMTP_PASSWORD", ""),
		SMTPFrom:         getEnv("SMTP_FROM", ""),
		ResendAPIKey:     getEnv("RESEND_API_KEY", ""),
		HTTPPort:         getEnv("HTTP_PORT", "8080"),
		WSPort:           getEnv("WS_PORT", "8081"),
		SuperAdminEmail:  getEnv("SUPERADMIN_EMAIL", ""),
		SuperAdminPass:   getEnv("SUPERADMIN_PASS", ""),
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
