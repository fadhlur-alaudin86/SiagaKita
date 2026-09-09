package incident

import (
	"testing"
)

func TestValidIncidentTypes(t *testing.T) {
	validTypes := []string{"medical", "fire", "crime", "rescue", "accident", "disaster", "general"}
	for _, it := range validTypes {
		if !validIncidentTypes[it] {
			t.Errorf("expected '%s' to be valid incident type", it)
		}
	}

	invalidTypes := []string{"hooligan", "ufo", "prank", "unknown", "invalid"}
	for _, it := range invalidTypes {
		if validIncidentTypes[it] {
			t.Errorf("expected '%s' to be invalid incident type", it)
		}
	}
}

func TestIncidentTypeMultipliers(t *testing.T) {
	expectedMultipliers := map[string]float64{
		"medical":  1.5,
		"fire":     1.3,
		"rescue":   1.4,
		"crime":    1.2,
		"accident": 1.3,
		"disaster": 1.4,
		"general":  1.0,
		"unknown":  1.0,
	}

	for it, expected := range expectedMultipliers {
		actual, ok := incidentTypeMultiplier[it]
		if !ok {
			t.Fatalf("multiplier for '%s' missing", it)
		}
		if actual != expected {
			t.Errorf("expected multiplier for '%s' to be %f, got %f", it, expected, actual)
		}
	}
}

func TestUpdateType_InvalidType(t *testing.T) {
	svc := &Service{}
	err := svc.UpdateType("inc-123", "user-123", "unregistered_type")
	if err == nil {
		t.Fatal("expected error for invalid incident type, got nil")
	}
	expected := "tipe insiden tidak valid: unregistered_type"
	if err.Error() != expected {
		t.Errorf("expected error '%s', got '%s'", expected, err.Error())
	}
}
