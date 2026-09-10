package i18n

import (
	"testing"
)

func TestParseAcceptLanguage(t *testing.T) {
	tests := []struct {
		name     string
		header   string
		expected string
	}{
		{"Empty header", "", LocaleID},
		{"Simple en", "en", LocaleEN},
		{"Simple id", "id", LocaleID},
		{"en-US locale", "en-US,en;q=0.9", LocaleEN},
		{"id-ID locale", "id-ID,id;q=0.9,en;q=0.8", LocaleID},
		{"Complex en priority", "en;q=0.9,id;q=0.5", LocaleEN},
		{"Complex id priority", "id-ID,id;q=0.9", LocaleID},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := parseAcceptLanguage(tt.header)
			if got != tt.expected {
				t.Errorf("parseAcceptLanguage(%q) = %q, want %q", tt.header, got, tt.expected)
			}
		})
	}
}

const testMsgInvalidBody = "Body request tidak valid"

func TestTranslate(t *testing.T) {
	tests := []struct {
		name     string
		lang     string
		msg      string
		expected string
	}{
		{
			name:     "Static translation to English",
			lang:     LocaleEN,
			msg:      testMsgInvalidBody,
			expected: "Invalid request body",
		},
		{
			name:     "Static translation to Indonesian (unchanged)",
			lang:     LocaleID,
			msg:      testMsgInvalidBody,
			expected: testMsgInvalidBody,
		},
		{
			name:     "Dynamic false alarm strike message in English",
			lang:     LocaleEN,
			msg:      "Insiden ditandai false alarm. Pelanggaran 2/3.",
			expected: "Incident marked as false alarm. Violation 2/3.",
		},
		{
			name:     "Dynamic invalid incident type in English",
			lang:     LocaleEN,
			msg:      "tipe insiden tidak valid: spaceship",
			expected: "Invalid incident type: spaceship",
		},
		{
			name:     "Unknown string fallback in English",
			lang:     LocaleEN,
			msg:      "Pesan yang belum terdaftar",
			expected: "Pesan yang belum terdaftar",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := Translate(tt.lang, tt.msg)
			if got != tt.expected {
				t.Errorf("Translate(%q, %q) = %q, want %q", tt.lang, tt.msg, got, tt.expected)
			}
		})
	}
}
