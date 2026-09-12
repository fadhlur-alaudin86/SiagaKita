package incident

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestBadgeUnlocked_Serialization(t *testing.T) {
	unlocked := BadgeUnlocked{
		BadgeCode:   "first_responder",
		BadgeName:   "First Responder I",
		Level:       1,
		Threshold:   1,
		Description: "Selesaikan 1 misi penyelamatan darurat pertama",
		IconURL:     "badge_first_responder_1",
	}

	data, err := json.Marshal(unlocked)
	assert.NoError(t, err)

	var parsed map[string]interface{}
	err = json.Unmarshal(data, &parsed)
	assert.NoError(t, err)
	assert.Equal(t, "first_responder", parsed["badge_code"])
	assert.Equal(t, "First Responder I", parsed["badge_name"])
	assert.Equal(t, float64(1), parsed["level"])
	assert.Equal(t, float64(1), parsed["threshold"])
}

func TestResolveResponse_WithBadges(t *testing.T) {
	resp := ResolveResponse{
		Resolved:     true,
		XPEarned:     150,
		NewTotalXP:   500,
		TotalRescues: 5,
		RankUp:       true,
		NewRank:      "Senior Responder",
		NewBadges: []BadgeUnlocked{
			{
				BadgeCode: "first_responder",
				BadgeName: "First Responder II",
				Level:     2,
				Threshold: 5,
			},
		},
	}

	data, err := json.Marshal(resp)
	assert.NoError(t, err)

	var parsed ResolveResponse
	err = json.Unmarshal(data, &parsed)
	assert.NoError(t, err)
	assert.True(t, parsed.Resolved)
	assert.Equal(t, 150, parsed.XPEarned)
	assert.Equal(t, 1, len(parsed.NewBadges))
	assert.Equal(t, "first_responder", parsed.NewBadges[0].BadgeCode)
	assert.Equal(t, 2, parsed.NewBadges[0].Level)
}

func TestMissionHistoryResponse_Serialization(t *testing.T) {
	dur := 12
	proof := "https://storage.siagakita.id/proofs/sos-123.jpg"
	addr := "Jl. Malioboro No. 1, Yogyakarta"

	item := MissionHistoryResponse{
		ID:              "sos-123",
		IncidentType:    "medical",
		Status:          "resolved",
		ResponseStatus:  "completed",
		AddressDetail:   &addr,
		AcceptedAt:      "2026-09-12T08:00:00Z",
		CompletedAt:     &[]string{"2026-09-12T08:12:00Z"}[0],
		DurationMinutes: &dur,
		ProofPhotoURL:   &proof,
		XPEarned:        140,
	}

	data, err := json.Marshal(item)
	assert.NoError(t, err)

	var parsed MissionHistoryResponse
	err = json.Unmarshal(data, &parsed)
	assert.NoError(t, err)
	assert.Equal(t, "sos-123", parsed.ID)
	assert.Equal(t, "medical", parsed.IncidentType)
	assert.Equal(t, "completed", parsed.ResponseStatus)
	assert.NotNil(t, parsed.DurationMinutes)
	assert.Equal(t, 12, *parsed.DurationMinutes)
	assert.NotNil(t, parsed.ProofPhotoURL)
	assert.Equal(t, proof, *parsed.ProofPhotoURL)
}

func TestBadgeCategoryProgress_GroupingLogic(t *testing.T) {
	now := time.Now().Format(time.RFC3339)
	tiers := []BadgeTierItem{
		{ID: "tier-1", Level: 1, Threshold: 1, Description: "Level 1", Earned: true, EarnedAt: &now},
		{ID: "tier-2", Level: 2, Threshold: 5, Description: "Level 2", Earned: true, EarnedAt: &now},
		{ID: "tier-3", Level: 3, Threshold: 15, Description: "Level 3", Earned: false},
	}

	nextTh := 15
	cat := BadgeCategoryProgress{
		BadgeCode:       "first_responder",
		BadgeName:       "First Responder",
		CurrentLevel:    2,
		MaxLevel:        3,
		CurrentProgress: 8,
		NextThreshold:   &nextTh,
		Tiers:           tiers,
	}

	assert.Equal(t, 2, cat.CurrentLevel)
	assert.Equal(t, 3, cat.MaxLevel)
	assert.Equal(t, 8, cat.CurrentProgress)
	assert.NotNil(t, cat.NextThreshold)
	assert.Equal(t, 15, *cat.NextThreshold)
	assert.True(t, cat.Tiers[0].Earned)
	assert.True(t, cat.Tiers[1].Earned)
	assert.False(t, cat.Tiers[2].Earned)
}
