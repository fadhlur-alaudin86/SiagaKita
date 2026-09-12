package notification

// Priority levels for push notifications
const (
	PriorityHigh = "high"
)

// PushPayload defines the structured notification and data payload delivered via FCM.
type PushPayload struct {
	IncidentID   string `json:"incident_id"`
	IncidentType string `json:"incident_type"`
	Title        string `json:"title"`
	Body         string `json:"body"`
	Latitude     string `json:"latitude"`
	Longitude    string `json:"longitude"`
	Address      string `json:"address,omitempty"`
	ChannelID    string `json:"channel_id"`
	Priority     string `json:"priority"`
	ClickAction  string `json:"click_action"`
}

// MulticastResult captures the delivery statistics and stale tokens identified by FCM.
type MulticastResult struct {
	SuccessCount int      `json:"success_count"`
	FailureCount int      `json:"failure_count"`
	StaleTokens  []string `json:"stale_tokens,omitempty"`
}
