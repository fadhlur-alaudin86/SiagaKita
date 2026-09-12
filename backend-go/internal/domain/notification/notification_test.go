package notification

import (
	"context"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type MockSender struct {
	CapturedPayload *PushPayload
	CapturedTokens  []string
	ReturnResult    *MulticastResult
	ReturnErr       error
}

func (m *MockSender) SendMulticast(ctx context.Context, payload PushPayload, tokens []string) (*MulticastResult, error) {
	m.CapturedPayload = &payload
	m.CapturedTokens = tokens
	return m.ReturnResult, m.ReturnErr
}

func TestNoOpLoggerSender_Delivery(t *testing.T) {
	sender := NewNoOpLoggerSender()
	payload := PushPayload{
		IncidentID:   "inc-123",
		IncidentType: "medical",
		Title:        "PERINGATAN DARURAT",
		Body:         "Ada insiden medis",
		Latitude:     "-6.2088",
		Longitude:    "106.8456",
		ChannelID:    "emergency_alerts",
		Priority:     "high",
		ClickAction:  "FLUTTER_NOTIFICATION_CLICK",
	}

	tokens := []string{"token-1", "token-2", "token-3"}
	res, err := sender.SendMulticast(context.Background(), payload, tokens)

	require.NoError(t, err)
	assert.Equal(t, 3, res.SuccessCount)
	assert.Equal(t, 0, res.FailureCount)
	assert.Nil(t, res.StaleTokens)
}

func TestNewSender_FallbackToNoOpWhenEmptyCredentials(t *testing.T) {
	sender, err := NewSender("", "")
	require.NoError(t, err)
	_, ok := sender.(*NoOpLoggerSender)
	assert.True(t, ok, "Expected NoOpLoggerSender when credentials are empty")
}

func TestNewSender_FallbackWhenMalformedCredentials(t *testing.T) {
	// Malformed JSON should gracefully fall back to NoOp logger without panicking
	sender, err := NewSender("", "not-valid-json")
	require.NoError(t, err)
	_, ok := sender.(*NoOpLoggerSender)
	assert.True(t, ok, "Expected fallback to NoOpLoggerSender on malformed credentials")
}

func TestPushPayload_Properties(t *testing.T) {
	payload := PushPayload{
		IncidentID:   "uuid-1234",
		IncidentType: "fire",
		Title:        "KEBAKARAN",
		Body:         "Kebakaran di Pasar Minggu",
		Latitude:     "-6.2844",
		Longitude:    "106.8444",
		Address:      "Pasar Minggu, Jakarta Selatan",
		ChannelID:    "emergency_alerts",
		Priority:     "high",
		ClickAction:  "FLUTTER_NOTIFICATION_CLICK",
	}

	assert.Equal(t, "emergency_alerts", payload.ChannelID)
	assert.Equal(t, "high", payload.Priority)
	assert.Equal(t, "FLUTTER_NOTIFICATION_CLICK", payload.ClickAction)
}

func TestNewSender_WithValidCredentialsEnv(t *testing.T) {
	creds := os.Getenv("FIREBASE_CREDENTIALS_JSON")
	if creds == "" {
		t.Skip("FIREBASE_CREDENTIALS_JSON not set")
	}
	sender, err := NewSender("", creds)
	require.NoError(t, err)
	_, ok := sender.(*FirebaseSender)
	assert.True(t, ok, "Expected FirebaseSender when valid credentials are provided")
}
