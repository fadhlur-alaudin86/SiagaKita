package otp

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// gmailAPIGateway mengirim email via Gmail REST API (port 443).
// Sangat berguna untuk VPS yang memblokir outbound port 25/465/587.
type gmailAPIGateway struct {
	clientID     string
	clientSecret string
	refreshToken string
	from         string
}

// NewGmailAPIGateway membuat instance email gateway menggunakan Gmail API.
func NewGmailAPIGateway(clientID, clientSecret, refreshToken, from string) EmailGateway {
	return &gmailAPIGateway{
		clientID:     clientID,
		clientSecret: clientSecret,
		refreshToken: refreshToken,
		from:         from,
	}
}

// getAccessToken menukar refresh token menjadi access token baru
func (g *gmailAPIGateway) getAccessToken() (string, error) {
	url := "https://oauth2.googleapis.com/token"
	payload := map[string]string{
		"client_id":     g.clientID,
		"client_secret": g.clientSecret,
		"refresh_token": g.refreshToken,
		"grant_type":    "refresh_token",
	}
	body, _ := json.Marshal(payload)
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewBuffer(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		respBody, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("gagal refresh token (status %d): %s", resp.StatusCode, string(respBody))
	}

	var result struct {
		AccessToken string `json:"access_token"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", err
	}
	return result.AccessToken, nil
}

// SendEmail mengirim email melalui endpoint messages.send milik Gmail API
func (g *gmailAPIGateway) SendEmail(toEmail, subject, body string) error {
	// 1. Dapatkan access token yang fresh
	accessToken, err := g.getAccessToken()
	if err != nil {
		return fmt.Errorf("gmail_api: %w", err)
	}

	// 2. Format email sesuai standar MIME (RFC 2822)
	msg := fmt.Sprintf("From: SiagaKita <%s>\r\nTo: %s\r\nSubject: %s\r\nMIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n%s",
		g.from, toEmail, subject, body)

	// 3. Encode menjadi Base64URL (syarat Gmail API)
	encoded := base64.URLEncoding.EncodeToString([]byte(msg))

	payload := map[string]string{
		"raw": encoded,
	}
	jsonPayload, _ := json.Marshal(payload)

	// 4. Kirim request HTTP POST ke Gmail API
	url := "https://gmail.googleapis.com/gmail/v1/users/me/messages/send"
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewBuffer(jsonPayload))
	if err != nil {
		return fmt.Errorf("gmail_api: gagal membuat HTTP request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("gmail_api: HTTP request gagal dikirim: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		return nil
	}

	respBody, _ := io.ReadAll(resp.Body)
	return fmt.Errorf("gmail_api: API merespons dengan error %d: %s", resp.StatusCode, string(respBody))
}
