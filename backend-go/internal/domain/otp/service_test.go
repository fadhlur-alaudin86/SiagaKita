package otp

import (
	"strconv"
	"testing"
)

type mockWAGateway struct {
	lastPhone   string
	lastMessage string
	sendErr     error
}

func (m *mockWAGateway) Send(phone, message string) error {
	m.lastPhone = phone
	m.lastMessage = message
	return m.sendErr
}

type mockEmailGateway struct {
	lastEmail   string
	lastSubject string
	lastBody    string
	sendErr     error
}

func (m *mockEmailGateway) SendEmail(toEmail, subject, body string) error {
	m.lastEmail = toEmail
	m.lastSubject = subject
	m.lastBody = body
	return m.sendErr
}

func TestNormalizePhone(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "standard Indonesian 08 prefix",
			input:    "081234567890",
			expected: "6281234567890",
		},
		{
			name:     "international format with plus",
			input:    "+6281234567890",
			expected: "6281234567890",
		},
		{
			name:     "already formatted without plus",
			input:    "6281234567890",
			expected: "6281234567890",
		},
		{
			name:     "with spaces and dashes",
			input:    "  0812 - 3456 - 7890  ",
			expected: "6281234567890",
		},
		{
			name:     "unrecognized non-Indonesian number returns trimmed",
			input:    "12345678",
			expected: "12345678",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := normalizePhone(tt.input)
			if result != tt.expected {
				t.Errorf("expected %q, got %q", tt.expected, result)
			}
		})
	}
}

func TestGenerateCode(t *testing.T) {
	seen := make(map[string]bool)

	for i := 0; i < 50; i++ {
		code := generateCode()

		// Verify 6 characters length
		if len(code) != 6 {
			t.Fatalf("expected code of length 6, got %d for code %q", len(code), code)
		}

		// Verify parses as numeric integer between 100000 and 999999
		n, err := strconv.Atoi(code)
		if err != nil {
			t.Fatalf("code %q is not numeric: %v", code, err)
		}
		if n < 100000 || n > 999999 {
			t.Fatalf("code %d out of expected range [100000, 999999]", n)
		}

		seen[code] = true
	}

	// Over 50 iterations, we should have generated multiple distinct codes
	if len(seen) < 10 {
		t.Errorf("suspicious lack of randomness: only %d distinct codes generated in 50 iterations", len(seen))
	}
}

func TestRedisKeyHelpers(t *testing.T) {
	phone := "6281234567890"
	expectedPhoneKey := "otp:phone:6281234567890"
	if key := otpKey(phone); key != expectedPhoneKey {
		t.Errorf("expected otpKey %q, got %q", expectedPhoneKey, key)
	}

	expectedPhoneCooldown := "otp_cooldown:phone:6281234567890"
	if key := phoneCooldownKey(phone); key != expectedPhoneCooldown {
		t.Errorf("expected phoneCooldownKey %q, got %q", expectedPhoneCooldown, key)
	}

	email := "user@siagakita.com"
	purpose := "password_reset"
	expectedEmailKey := "otp:email:password_reset:user@siagakita.com"
	if key := emailOTPKey(email, purpose); key != expectedEmailKey {
		t.Errorf("expected emailOTPKey %q, got %q", expectedEmailKey, key)
	}

	expectedEmailCooldown := "otp_cooldown:email:user@siagakita.com"
	if key := emailCooldownKey(email); key != expectedEmailCooldown {
		t.Errorf("expected emailCooldownKey %q, got %q", expectedEmailCooldown, key)
	}
}

func TestNewServiceAndGateway(t *testing.T) {
	mockWA := &mockWAGateway{}
	mockEmail := &mockEmailGateway{}

	svc := NewService(nil, mockWA, mockEmail)
	if svc == nil {
		t.Fatal("expected non-nil Service instance")
	}

	gw := NewFonnteGateway("dummy-fonnte-token")
	if gw == nil {
		t.Fatal("expected non-nil Gateway instance from NewFonnteGateway")
	}
}
