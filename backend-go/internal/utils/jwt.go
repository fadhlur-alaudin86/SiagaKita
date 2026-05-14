package utils

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

// Claims is the custom JWT payload.
type Claims struct {
	UserID string `json:"user_id"`
	Role   string `json:"role"`
	JTI    string `json:"jti"` // JWT ID — unique per token, used for session allowlist
	jwt.RegisteredClaims
}

// GenerateAccessToken generates a short-lived access token with a unique JTI.
func GenerateAccessToken(userID, role, secret string, ttl time.Duration) (string, string, error) {
	jti := uuid.New().String()
	token, err := newSignedToken(userID, role, jti, secret, ttl)
	return token, jti, err
}

// GenerateRefreshToken generates a long-lived refresh token with a unique JTI.
func GenerateRefreshToken(userID, role, secret string, ttl time.Duration) (string, string, error) {
	jti := uuid.New().String()
	token, err := newSignedToken(userID, role, jti, secret, ttl)
	return token, jti, err
}

// ParseToken validates and parses a JWT string into Claims.
func ParseToken(tokenStr, secret string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenStr, &Claims{}, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return []byte(secret), nil
	})
	if err != nil {
		return nil, err
	}

	if claims, ok := token.Claims.(*Claims); ok && token.Valid {
		return claims, nil
	}
	return nil, errors.New("invalid token")
}

func newSignedToken(userID, role, jti, secret string, ttl time.Duration) (string, error) {
	claims := Claims{
		UserID: userID,
		Role:   role,
		JTI:    jti,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(ttl)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			ID:        jti,
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(secret))
}

