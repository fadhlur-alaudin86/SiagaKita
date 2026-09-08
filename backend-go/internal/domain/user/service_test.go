package user

import (
	"context"
	"testing"

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
