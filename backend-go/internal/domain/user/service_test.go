package user

import (
	"context"
	"testing"
	"time"

	"siagakita-backend/internal/config"
	"siagakita-backend/internal/utils"

	"golang.org/x/crypto/bcrypt"
)

func TestRegister_Validation(t *testing.T) {
	svc := &Service{}

	tests := []struct {
		name        string
		req         RegisterRequest
		expectedErr string
	}{
		{
			name:        "Empty fields",
			req:         RegisterRequest{FullName: "", Email: "", Password: ""},
			expectedErr: "full_name, email, dan password wajib diisi",
		},
		{
			name:        "Password too short",
			req:         RegisterRequest{FullName: "John Doe", Email: "john@example.com", Password: "short"},
			expectedErr: "password minimal 8 karakter",
		},
		{
			name:        "Missing password",
			req:         RegisterRequest{FullName: "John Doe", Email: "john@example.com", Password: ""},
			expectedErr: "full_name, email, dan password wajib diisi",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			_, err := svc.Register(context.Background(), &tc.req)
			if err == nil {
				t.Fatalf("expected error '%s', got nil", tc.expectedErr)
			}
			if err.Error() != tc.expectedErr {
				t.Errorf("expected error '%s', got '%s'", tc.expectedErr, err.Error())
			}
		})
	}
}

func TestResetPassword_Validation(t *testing.T) {
	svc := &Service{}

	err := svc.ResetPassword(context.Background(), "user@example.com", "123456", "short")
	if err == nil || err.Error() != "password minimal 8 karakter" {
		t.Fatalf("expected 'password minimal 8 karakter', got %v", err)
	}
}

func TestBcryptPasswordHashing(t *testing.T) {
	password := "SecureP@ssw0rd123!"
	hashed, err := bcrypt.GenerateFromPassword([]byte(password), 12)
	if err != nil {
		t.Fatalf("failed to generate bcrypt hash: %v", err)
	}

	if err := bcrypt.CompareHashAndPassword(hashed, []byte(password)); err != nil {
		t.Errorf("expected hash to match password: %v", err)
	}

	if err := bcrypt.CompareHashAndPassword(hashed, []byte("WrongP@ssw0rd")); err == nil {
		t.Error("expected hash comparison to fail for wrong password")
	}
}

func TestRefreshToken_Validation(t *testing.T) {
	cfg := &config.Config{
		JWTSecret:    "test-jwt-secret-key-32-chars-long!",
		JWTAccessTTL: 15 * time.Minute,
		JWTRefreshTTL: 7 * 24 * time.Hour,
	}
	svc := &Service{cfg: cfg}

	// 1. Empty refresh token
	_, err := svc.RefreshToken(context.Background(), "")
	if err == nil || err.Error() != "refresh_token wajib diisi" {
		t.Errorf("expected 'refresh_token wajib diisi', got %v", err)
	}

	// 2. Malformed token string
	_, err = svc.RefreshToken(context.Background(), "malformed.jwt.token")
	if err == nil || err.Error() != "token refresh tidak valid atau sudah kedaluwarsa" {
		t.Errorf("expected invalid token error, got %v", err)
	}

	// 3. Access token passed instead of refresh token
	accessToken, _, err := utils.GenerateAccessToken("user-1", "civilian", cfg.JWTSecret, cfg.JWTAccessTTL)
	if err != nil {
		t.Fatalf("failed to generate access token: %v", err)
	}
	_, err = svc.RefreshToken(context.Background(), accessToken)
	if err == nil || err.Error() != "tipe token tidak valid" {
		t.Errorf("expected 'tipe token tidak valid', got %v", err)
	}

	// 4. Expired refresh token
	expiredRefresh, _, err := utils.GenerateRefreshToken("user-1", "civilian", cfg.JWTSecret, -1*time.Hour)
	if err != nil {
		t.Fatalf("failed to generate expired refresh token: %v", err)
	}
	_, err = svc.RefreshToken(context.Background(), expiredRefresh)
	if err == nil || err.Error() != "token refresh tidak valid atau sudah kedaluwarsa" {
		t.Errorf("expected expired token error, got %v", err)
	}
}
