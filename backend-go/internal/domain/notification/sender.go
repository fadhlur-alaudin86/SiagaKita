package notification

import (
	"context"
	"strings"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
	"siagakita-backend/internal/utils"
)

// Sender abstracts the push notification transport layer.
type Sender interface {
	SendMulticast(ctx context.Context, payload PushPayload, tokens []string) (*MulticastResult, error)
}

// ─── Firebase Admin SDK Sender ───────────────────────────────────────────────

type FirebaseSender struct {
	client *messaging.Client
}

func NewFirebaseSender(client *messaging.Client) *FirebaseSender {
	return &FirebaseSender{client: client}
}

func (s *FirebaseSender) SendMulticast(ctx context.Context, payload PushPayload, tokens []string) (*MulticastResult, error) {
	if len(tokens) == 0 {
		return &MulticastResult{SuccessCount: 0, FailureCount: 0}, nil
	}

	result := &MulticastResult{
		StaleTokens: make([]string, 0),
	}

	// FCM limit per multicast request is 500 tokens
	const batchSize = 500

	dataMap := map[string]string{
		"incident_id":   payload.IncidentID,
		"incident_type": payload.IncidentType,
		"title":         payload.Title,
		"body":          payload.Body,
		"latitude":      payload.Latitude,
		"longitude":     payload.Longitude,
		"address":       payload.Address,
		"channel_id":    payload.ChannelID,
		"priority":      payload.Priority,
		"click_action":  payload.ClickAction,
	}

	for i := 0; i < len(tokens); i += batchSize {
		end := i + batchSize
		if end > len(tokens) {
			end = len(tokens)
		}
		batch := tokens[i:end]

		msg := &messaging.MulticastMessage{
			Tokens: batch, //nolint:staticcheck // SA1019: FCM client device registration tokens are passed via Tokens
			Data:   dataMap,
			Notification: &messaging.Notification{
				Title: payload.Title,
				Body:  payload.Body,
			},
			Android: &messaging.AndroidConfig{
				Priority: "high",
				Notification: &messaging.AndroidNotification{
					ChannelID:   payload.ChannelID,
					ClickAction: payload.ClickAction,
					Sound:       "alarm",
				},
			},
			APNS: &messaging.APNSConfig{
				Payload: &messaging.APNSPayload{
					Aps: &messaging.Aps{
						Sound:    "alarm.caf",
						Category: payload.ClickAction,
					},
				},
			},
		}

		br, err := s.client.SendEachForMulticast(ctx, msg)
		if err != nil {
			utils.Error().Err(err).Int("batch_size", len(batch)).Msg("[FirebaseSender] Failed to send multicast batch")
			result.FailureCount += len(batch)
			continue
		}

		result.SuccessCount += br.SuccessCount
		result.FailureCount += br.FailureCount

		for idx, resp := range br.Responses {
			if !resp.Success && resp.Error != nil {
				if messaging.IsUnregistered(resp.Error) ||
					strings.Contains(strings.ToLower(resp.Error.Error()), "registration-token-not-registered") ||
					strings.Contains(strings.ToLower(resp.Error.Error()), "unregistered") {
					result.StaleTokens = append(result.StaleTokens, batch[idx])
				}
			}
		}
	}

	utils.Info().
		Int("success", result.SuccessCount).
		Int("failed", result.FailureCount).
		Int("stale", len(result.StaleTokens)).
		Str("incident_id", payload.IncidentID).
		Msg("[FirebaseSender] FCM multicast broadcast completed")

	return result, nil
}

// ─── No-Op / Logger Sender (CI & Local Dev Fallback) ──────────────────────────

type NoOpLoggerSender struct{}

func NewNoOpLoggerSender() *NoOpLoggerSender {
	return &NoOpLoggerSender{}
}

func (s *NoOpLoggerSender) SendMulticast(ctx context.Context, payload PushPayload, tokens []string) (*MulticastResult, error) {
	utils.Info().
		Str("title", payload.Title).
		Str("incident_id", payload.IncidentID).
		Str("channel_id", payload.ChannelID).
		Int("recipient_tokens", len(tokens)).
		Msg("[NoOpLoggerSender] Simulated FCM push notification delivery (Dry-Run)")

	return &MulticastResult{
		SuccessCount: len(tokens),
		FailureCount: 0,
		StaleTokens:  nil,
	}, nil
}

// ─── Factory ─────────────────────────────────────────────────────────────────

// NewSender creates a FirebaseSender if credentials are provided, or a NoOpLoggerSender otherwise.
func NewSender(credentialsFile, credentialsJSON string) (Sender, error) {
	var opts []option.ClientOption

	if strings.TrimSpace(credentialsJSON) != "" {
		opts = append(opts, option.WithCredentialsJSON([]byte(credentialsJSON))) //nolint:staticcheck // SA1019: trusted server config
	} else if strings.TrimSpace(credentialsFile) != "" {
		opts = append(opts, option.WithCredentialsFile(credentialsFile)) //nolint:staticcheck // SA1019: trusted server config
	} else {
		utils.Info().Msg("[Notification] No Firebase credentials provided; using No-Op Logger Sender (Dry-Run)")
		return NewNoOpLoggerSender(), nil
	}

	app, err := firebase.NewApp(context.Background(), nil, opts...)
	if err != nil {
		utils.Warn().Err(err).Msg("[Notification] Failed to initialize Firebase App; falling back to No-Op Logger")
		return NewNoOpLoggerSender(), nil
	}

	client, err := app.Messaging(context.Background())
	if err != nil {
		utils.Warn().Err(err).Msg("[Notification] Failed to initialize Firebase Messaging client; falling back to No-Op Logger")
		return NewNoOpLoggerSender(), nil
	}

	utils.Info().Msg("[Notification] Firebase Admin SDK messaging client initialized successfully")
	return NewFirebaseSender(client), nil
}
