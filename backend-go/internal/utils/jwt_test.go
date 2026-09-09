package utils

import (
	"strings"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

func TestGenerateAccessToken(t *testing.T) {
	secret := "test-jwt-secret-key-32-chars-long!"
	userID := "user-uuid-12345"
	role := "volunteer"
	ttl := 15 * time.Minute

	token, jti, err := GenerateAccessToken(userID, role, secret, ttl)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if token == "" {
		t.Fatal("expected non-empty token string")
	}
	if jti == "" {
		t.Fatal("expected non-empty JTI")
	}

	claims, err := ParseToken(token, secret)
	if err != nil {
		t.Fatalf("failed to parse generated token: %v", err)
	}

	if claims.UserID != userID {
		t.Errorf("expected UserID %s, got %s", userID, claims.UserID)
	}
	if claims.Role != role {
		t.Errorf("expected Role %s, got %s", role, claims.Role)
	}
	if claims.JTI != jti {
		t.Errorf("expected JTI %s, got %s", jti, claims.JTI)
	}
}

func TestGenerateRefreshToken(t *testing.T) {
	secret := "test-jwt-secret-key-32-chars-long!"
	userID := "user-uuid-67890"
	role := "civilian"
	ttl := 7 * 24 * time.Hour

	token, jti, err := GenerateRefreshToken(userID, role, secret, ttl)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if token == "" {
		t.Fatal("expected non-empty refresh token")
	}
	if jti == "" {
		t.Fatal("expected non-empty JTI")
	}

	claims, err := ParseToken(token, secret)
	if err != nil {
		t.Fatalf("failed to parse generated refresh token: %v", err)
	}
	if claims.UserID != userID || claims.Role != role || claims.JTI != jti {
		t.Errorf("claims mismatch: %+v", claims)
	}
}

func TestParseToken_Expired(t *testing.T) {
	secret := "test-jwt-secret-key-32-chars-long!"
	// Generate token that expired 1 hour ago
	token, _, err := GenerateAccessToken("expired-user", "civilian", secret, -1*time.Hour)
	if err != nil {
		t.Fatalf("unexpected error generating expired token: %v", err)
	}

	claims, err := ParseToken(token, secret)
	if err == nil {
		t.Fatalf("expected error for expired token, got nil claims: %+v", claims)
	}
}

func TestParseToken_InvalidSecret(t *testing.T) {
	token, _, err := GenerateAccessToken("user-1", "civilian", "correct-secret", 15*time.Minute)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	claims, err := ParseToken(token, "wrong-secret-key")
	if err == nil {
		t.Fatalf("expected error for invalid secret, got nil claims: %+v", claims)
	}
}

func TestParseToken_Malformed(t *testing.T) {
	malformedTokens := []string{
		"",
		"invalid-token-string",
		"header.payload",
		"a.b.c.d",
	}

	for _, malformed := range malformedTokens {
		_, err := ParseToken(malformed, "secret")
		if err == nil {
			t.Errorf("expected error for malformed token %q, got nil", malformed)
		}
	}
}

func TestParseToken_UnexpectedSigningMethod(t *testing.T) {
	// Craft a token with None signing method
	claims := Claims{
		UserID: "attacker",
		Role:   "superadmin",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(1 * time.Hour)),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodNone, claims)
	tokenStr, err := token.SignedString(jwt.UnsafeAllowNoneSignatureType)
	if err != nil {
		t.Fatalf("failed to craft unsigned token: %v", err)
	}

	_, err = ParseToken(tokenStr, "secret")
	if err == nil || !strings.Contains(err.Error(), "unexpected signing method") {
		t.Errorf("expected unexpected signing method error, got: %v", err)
	}
}
