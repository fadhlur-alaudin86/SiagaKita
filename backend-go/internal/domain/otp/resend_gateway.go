package otp

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

// resendEmailGateway mengirim email via Resend HTTP API (port 443).
// Tidak memerlukan port SMTP (25/465/587) — cocok untuk VPS yang memblokir SMTP.
// Dokumentasi: https://resend.com/docs/api-reference/emails/send-email
type resendEmailGateway struct {
	apiKey string
	from   string
}

// NewResendEmailGateway membuat instance email gateway menggunakan Resend API.
// apiKey: API key dari dashboard resend.com
// from:   Alamat pengirim (harus domain terverifikasi di Resend, atau gunakan "onboarding@resend.dev" untuk testing)
func NewResendEmailGateway(apiKey, from string) EmailGateway {
	return &resendEmailGateway{apiKey: apiKey, from: from}
}

type resendRequest struct {
	From    string   `json:"from"`
	To      []string `json:"to"`
	Subject string   `json:"subject"`
	Text    string   `json:"text"`
}

type resendErrorResponse struct {
	Name       string `json:"name"`
	Message    string `json:"message"`
	StatusCode int    `json:"statusCode"`
}

// SendEmail mengirim email via Resend HTTP API dengan timeout 15 detik.
func (g *resendEmailGateway) SendEmail(toEmail, subject, body string) error {
	payload := resendRequest{
		From:    g.from,
		To:      []string{toEmail},
		Subject: subject,
		Text:    body,
	}

	data, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("resend: marshal payload gagal: %w", err)
	}

	req, err := http.NewRequest(http.MethodPost, "https://api.resend.com/emails", bytes.NewBuffer(data))
	if err != nil {
		return fmt.Errorf("resend: buat HTTP request gagal: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+g.apiKey)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("resend: HTTP request gagal: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		return nil
	}

	// Decode error response dari Resend
	var errResp resendErrorResponse
	if decErr := json.NewDecoder(resp.Body).Decode(&errResp); decErr == nil && errResp.Message != "" {
		return fmt.Errorf("resend: gagal mengirim email (%d): %s", resp.StatusCode, errResp.Message)
	}
	return fmt.Errorf("resend: HTTP status tidak diharapkan: %d", resp.StatusCode)
}
