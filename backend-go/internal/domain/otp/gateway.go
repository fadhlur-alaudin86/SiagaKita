package otp

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
)

// Gateway mendefinisikan kontrak pengiriman pesan OTP (SMS/WhatsApp).
type Gateway interface {
	Send(phone, message string) error
}

// EmailGateway mendefinisikan kontrak pengiriman email OTP.
type EmailGateway interface {
	SendEmail(toEmail, subject, body string) error
}

// ─── Fonnte Gateway ──────────────────────────────────────────────────────────

// fonnteGateway mengirim pesan WhatsApp via API Fonnte.
type fonnteGateway struct {
	token string
}

// NewFonnteGateway membuat instance FonnteGateway dengan token yang diberikan.
func NewFonnteGateway(token string) Gateway {
	return &fonnteGateway{token: token}
}

type fonnteResponse struct {
	Status  bool   `json:"status"`
	Message string `json:"message"`
}

// Send mengirim pesan ke nomor HP via Fonnte API.
// Nomor harus dalam format +628xxx atau 08xxx (akan dinormalisasi ke 628xxx).
func (g *fonnteGateway) Send(phone, message string) error {
	// Normalisasi nomor: 08xxx → 628xxx
	normalized := normalizePhone(phone)

	form := url.Values{}
	form.Set("target", normalized)
	form.Set("message", message)
	form.Set("delay", "0")
	form.Set("countryCode", "62")

	req, err := http.NewRequest(http.MethodPost,
		"https://api.fonnte.com/send",
		strings.NewReader(form.Encode()),
	)
	if err != nil {
		return fmt.Errorf("otp/gateway: membuat request gagal: %w", err)
	}

	req.Header.Set("Authorization", g.token)
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("otp/gateway: request ke Fonnte gagal: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()

	body, _ := io.ReadAll(resp.Body)

	var result fonnteResponse
	if jsonErr := json.Unmarshal(body, &result); jsonErr != nil {
		return fmt.Errorf("otp/gateway: parse response gagal: %w", jsonErr)
	}

	if !result.Status {
		return fmt.Errorf("otp/gateway: Fonnte menolak pengiriman: %s", result.Message)
	}

	return nil
}

// normalizePhone mengubah format nomor Indonesia ke format internasional tanpa +.
// Contoh: 081234567890 → 6281234567890, +6281234 → 6281234
func normalizePhone(phone string) string {
	phone = strings.TrimSpace(phone)
	phone = strings.ReplaceAll(phone, " ", "")
	phone = strings.ReplaceAll(phone, "-", "")

	if strings.HasPrefix(phone, "+62") {
		return phone[1:] // hapus "+"
	}
	if strings.HasPrefix(phone, "62") {
		return phone
	}
	if strings.HasPrefix(phone, "0") {
		return "62" + phone[1:]
	}
	return phone
}
