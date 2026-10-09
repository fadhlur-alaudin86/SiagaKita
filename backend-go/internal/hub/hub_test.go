package hub

import "testing"

func TestLocaleOf(t *testing.T) {
	h := New()

	if got := h.LocaleOf("ghost"); got != "id" {
		t.Errorf("expected default id for unknown user, got %q", got)
	}

	h.Register("user-en", "civilian", "conn-1", nil, "en")
	if got := h.LocaleOf("user-en"); got != "en" {
		t.Errorf("expected en, got %q", got)
	}

	h.Register("user-id", "civilian", "conn-2", nil, "id")
	if got := h.LocaleOf("user-id"); got != "id" {
		t.Errorf("expected id, got %q", got)
	}
}
