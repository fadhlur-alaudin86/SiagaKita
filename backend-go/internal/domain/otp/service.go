package otp

import (
	"context"
	"errors"
	"fmt"
	"math/rand"
	"time"

	"github.com/redis/go-redis/v9"
)

const (
	otpTTL      = 3 * time.Minute // OTP kedaluwarsa dalam 3 menit
	cooldownTTL = 1 * time.Minute // Cooldown 1 menit antar request
)

// Service mendefinisikan kontrak logika bisnis OTP.
type Service interface {
	// ── Phone OTP (WhatsApp via Fonnte) ──────────────────────────────────────
	// RequestOTP membuat kode OTP, menyimpan ke Redis, dan mengirim via WA.
	RequestOTP(ctx context.Context, phone string) error
	// VerifyOTP memverifikasi kode OTP nomor HP (anti-replay).
	VerifyOTP(ctx context.Context, phone, code string) error

	// ── Email OTP (SMTP) ──────────────────────────────────────────────────────
	// RequestEmailOTP membuat kode OTP dan mengirimkannya via email.
	RequestEmailOTP(ctx context.Context, email, purpose string) error
	// VerifyEmailOTP memverifikasi kode OTP email (anti-replay).
	VerifyEmailOTP(ctx context.Context, email, purpose, code string) error
}

type service struct {
	rdb          *redis.Client
	waGateway    Gateway      // WhatsApp (Fonnte)
	emailGateway EmailGateway // SMTP
}

// NewService membuat instance OTP service dengan kedua gateway.
func NewService(rdb *redis.Client, waGateway Gateway, emailGateway EmailGateway) Service {
	return &service{rdb: rdb, waGateway: waGateway, emailGateway: emailGateway}
}

// ─── Redis Key Helpers ────────────────────────────────────────────────────────

// Phone keys
func otpKey(phone string) string {
	return fmt.Sprintf("otp:phone:%s", phone)
}

func phoneCooldownKey(phone string) string {
	return fmt.Sprintf("otp_cooldown:phone:%s", phone)
}

// Email keys — purpose memisahkan konteks: "register", "login", "reset"
func emailOTPKey(email, purpose string) string {
	return fmt.Sprintf("otp:email:%s:%s", purpose, email)
}

func emailCooldownKey(email string) string {
	return fmt.Sprintf("otp_cooldown:email:%s", email)
}

// ─── generateCode ─────────────────────────────────────────────────────────────

//nolint:gosec // OTP tidak butuh CSPRNG
func generateCode() string {
	return fmt.Sprintf("%06d", rand.Intn(900000)+100000)
}

// ─── Phone OTP (WhatsApp) ─────────────────────────────────────────────────────

func (s *service) RequestOTP(ctx context.Context, phone string) error {
	// Rate limit
	if exists, err := s.rdb.Exists(ctx, phoneCooldownKey(phone)).Result(); err != nil {
		return fmt.Errorf("otp: cek cooldown phone gagal: %w", err)
	} else if exists > 0 {
		return ErrCooldown
	}

	code := generateCode()

	if err := s.rdb.Set(ctx, otpKey(phone), code, otpTTL).Err(); err != nil {
		return fmt.Errorf("otp: simpan OTP phone gagal: %w", err)
	}
	if err := s.rdb.Set(ctx, phoneCooldownKey(phone), "1", cooldownTTL).Err(); err != nil {
		return fmt.Errorf("otp: simpan cooldown phone gagal: %w", err)
	}

	message := fmt.Sprintf(
		"%s adalah kode verifikasi WhatsApp SiagaKita Anda. Berlaku 3 menit. JANGAN BERIKAN KE SIAPAPUN.",
		code,
	)
	if err := s.waGateway.Send(phone, message); err != nil {
		_ = s.rdb.Del(ctx, otpKey(phone), phoneCooldownKey(phone))
		return fmt.Errorf("otp: kirim WA gagal: %w", err)
	}

	return nil
}

func (s *service) VerifyOTP(ctx context.Context, phone, code string) error {
	return s.verifyFromRedis(ctx, otpKey(phone), code, "nomor HP")
}

// ─── Email OTP (SMTP) ─────────────────────────────────────────────────────────

func (s *service) RequestEmailOTP(ctx context.Context, email, purpose string) error {
	// Rate limit (shared per email, regardless of purpose)
	if exists, err := s.rdb.Exists(ctx, emailCooldownKey(email)).Result(); err != nil {
		return fmt.Errorf("otp: cek cooldown email gagal: %w", err)
	} else if exists > 0 {
		return ErrCooldown
	}

	code := generateCode()

	key := emailOTPKey(email, purpose)
	if err := s.rdb.Set(ctx, key, code, otpTTL).Err(); err != nil {
		return fmt.Errorf("otp: simpan OTP email gagal: %w", err)
	}
	if err := s.rdb.Set(ctx, emailCooldownKey(email), "1", cooldownTTL).Err(); err != nil {
		return fmt.Errorf("otp: simpan cooldown email gagal: %w", err)
	}

	subject, body := buildEmailContent(purpose, code)
	if err := s.emailGateway.SendEmail(email, subject, body); err != nil {
		_ = s.rdb.Del(ctx, key, emailCooldownKey(email))
		return fmt.Errorf("otp: kirim email gagal: %w", err)
	}

	return nil
}

func (s *service) VerifyEmailOTP(ctx context.Context, email, purpose, code string) error {
	return s.verifyFromRedis(ctx, emailOTPKey(email, purpose), code, "email")
}

// ─── Shared verify logic ──────────────────────────────────────────────────────

func (s *service) verifyFromRedis(ctx context.Context, key, code, label string) error {
	stored, err := s.rdb.Get(ctx, key).Result()
	if err != nil {
		if errors.Is(err, redis.Nil) {
			return fmt.Errorf("OTP %s kedaluwarsa atau tidak ditemukan", label)
		}
		return fmt.Errorf("otp: ambil OTP gagal: %w", err)
	}
	if stored != code {
		return ErrInvalidOTP
	}
	_ = s.rdb.Del(ctx, key) // anti-replay
	return nil
}

// ─── Email template ───────────────────────────────────────────────────────────

func buildEmailContent(purpose, code string) (subject, body string) {
	switch purpose {
	case "register":
		subject = "[SiagaKita] Verifikasi Email Pendaftaran"
		body = fmt.Sprintf(
			"Halo!\n\nKode verifikasi email Anda untuk mendaftar di SiagaKita:\n\n"+
				"    %s\n\n"+
				"Kode berlaku 3 menit. JANGAN berikan kode ini ke siapapun.\n\n"+
				"Jika Anda tidak mendaftar, abaikan email ini.\n\n"+
				"Tim SiagaKita",
			code,
		)
	case "login":
		subject = "[SiagaKita] Kode Masuk (Login OTP)"
		body = fmt.Sprintf(
			"Halo!\n\nSeseorang (semoga Anda) mencoba masuk ke akun SiagaKita.\n\n"+
				"Kode masuk Anda:\n\n"+
				"    %s\n\n"+
				"Kode berlaku 3 menit. JANGAN berikan kode ini ke siapapun.\n\n"+
				"Jika bukan Anda, segera ganti password Anda.\n\n"+
				"Tim SiagaKita",
			code,
		)
	default:
		subject = "[SiagaKita] Kode OTP"
		body = fmt.Sprintf("Kode OTP Anda: %s\n\nBerlaku 3 menit.", code)
	}
	return subject, body
}
