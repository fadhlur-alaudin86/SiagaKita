package incident

import (
	"time"

	"github.com/lib/pq"
)

// ─── DB Models ────────────────────────────────────────────────────────────────

// Incident merepresentasikan SOS darurat dari masyarakat (Jalur A).
type Incident struct {
	ID                 string     `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	ReporterID         string     `gorm:"type:uuid;not null" json:"reporter_id"`
	IncidentType       string     `gorm:"default:'unknown'" json:"incident_type"` // incident_category enum
	Latitude           float64    `gorm:"not null" json:"latitude"`
	Longitude          float64    `gorm:"not null" json:"longitude"`
	Status             string     `gorm:"default:'grace_period'" json:"status"`
	TriggerMethod      string     `gorm:"default:'user'" json:"trigger_method"` // 'user' | 'timeout'
	UrgencyLevel       string     `gorm:"default:'critical'" json:"urgency_level"`
	ReporterTrustLabel string     `gorm:"default:'standard'" json:"reporter_trust_label"` // 'verified'|'standard'|'unverified'
	AddressDetail      *string    `json:"address_detail,omitempty"`
	CreatedAt          time.Time  `json:"created_at"`
	UpdatedAt          time.Time  `json:"updated_at"`
	ResolvedAt         *time.Time `json:"resolved_at,omitempty"`
}

// IncidentReport merepresentasikan laporan warga non-darurat (Jalur B).
type IncidentReport struct {
	ID           string         `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	ReporterID   string         `gorm:"type:uuid;not null" json:"reporter_id"`
	IncidentType string         `gorm:"not null" json:"incident_type"`
	UrgencyLevel int            `gorm:"default:1" json:"urgency_level"` // 0=ringan, 1=sedang, 2=kritis
	Latitude     float64        `gorm:"not null" json:"latitude"`
	Longitude    float64        `gorm:"not null" json:"longitude"`
	Description  *string        `json:"description,omitempty"`
	PhotoPaths   pq.StringArray `gorm:"type:text[]" json:"photo_paths"`
	AudioPath    *string        `json:"audio_path,omitempty"`
	Status       string         `gorm:"default:'received'" json:"status"`
	CreatedAt    time.Time      `json:"created_at"`
	UpdatedAt    time.Time      `json:"updated_at"`
}

// SOSStrike adalah audit log setiap kali admin menandai false alarm.
type SOSStrike struct {
	ID         string    `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	UserID     string    `gorm:"type:uuid;not null" json:"user_id"`
	IncidentID *string   `gorm:"type:uuid" json:"incident_id,omitempty"`
	Reason     string    `json:"reason"`
	GivenBy    *string   `gorm:"type:uuid" json:"given_by,omitempty"` // admin UUID
	CreatedAt  time.Time `json:"created_at"`
}

// IncidentResponse adalah respons relawan/instansi terhadap incident.
type IncidentResponse struct {
	ID          string     `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	IncidentID  string     `gorm:"type:uuid;not null" json:"incident_id"`
	ResponderID string     `gorm:"type:uuid;not null" json:"responder_id"`
	Status      string     `gorm:"default:'en_route'" json:"status"`
	AcceptedAt  *time.Time `json:"accepted_at,omitempty"`
	ArrivedAt   *time.Time `json:"arrived_at,omitempty"`
}

// VolunteerReputation menyimpan poin XP dan total rescue relawan.
type VolunteerReputation struct {
	UserID       string    `gorm:"type:uuid;primaryKey" json:"user_id"`
	ExpPoints    int       `gorm:"default:0" json:"exp_points"`
	RankID       *uint     `json:"rank_id,omitempty"`
	TotalRescues int       `gorm:"default:0" json:"total_rescues"`
	UpdatedAt    time.Time `json:"updated_at"`
}

type MRank struct {
	ID       uint   `gorm:"primaryKey" json:"id"`
	RankName string `json:"rank_name"`
	MinExp   int    `json:"min_exp"`
	IconURL  string `json:"icon_url"`
}

// ─── Request DTOs ─────────────────────────────────────────────────────────────

// TriggerSOSRequest — Jalur A: hanya GPS wajib, tipe selalu mulai 'unknown'.
type TriggerSOSRequest struct {
	Latitude      float64 `json:"latitude"`
	Longitude     float64 `json:"longitude"`
	TriggerMethod string  `json:"trigger_method"` // 'user' | 'timeout'
}

// UpdateTypeRequest — dikirim dari grace period UI saat user memilih tipe.
type UpdateTypeRequest struct {
	IncidentType string `json:"incident_type"` // 'medical'|'fire'|'crime'|'rescue'|'general'
}

// UpdateLocationRequest — dikirim tiap 1 menit selama SOS aktif.
type UpdateLocationRequest struct {
	IncidentID string  `json:"incident_id"`
	Latitude   float64 `json:"latitude"`
	Longitude  float64 `json:"longitude"`
}

// MarkFalseAlarmRequest — admin menandai insiden sebagai false alarm.
type MarkFalseAlarmRequest struct {
	Reason string `json:"reason"`
}

// CreateReportRequest — Jalur B: laporan warga non-darurat (multipart/form-data).
type CreateReportRequest struct {
	IncidentType string  `form:"incident_type"` // wajib
	UrgencyLevel int     `form:"urgency_level"` // 0=ringan, 1=sedang, 2=kritis
	Latitude     float64 `form:"latitude"`
	Longitude    float64 `form:"longitude"`
	Description  string  `form:"description"`
}

// ─── Response DTOs ─────────────────────────────────────────────────────────────

// TriggerSOSResponse dikirim ke Flutter setelah SOS berhasil dibuat.
type TriggerSOSResponse struct {
	IncidentID string `json:"incident_id"`
	Status     string `json:"status"`
	Message    string `json:"message"`
}

// ActiveIncidentResponse — data SOS aktif milik reporter.
type ActiveIncidentResponse struct {
	IncidentID         string  `json:"incident_id"`
	Status             string  `json:"status"`
	IncidentType       string  `json:"incident_type"`
	Latitude           float64 `json:"latitude"`
	Longitude          float64 `json:"longitude"`
	CreatedAt          string  `json:"created_at"`
	ReporterTrustLabel string  `json:"reporter_trust_label"`
}

// AllActiveIncidentResponse — data SOS aktif LENGKAP untuk console desktop (JOIN ke users & profiles).
type AllActiveIncidentResponse struct {
	ID                 string  `json:"id"`
	ReporterID         string  `json:"reporter_id"`
	ReporterName       string  `json:"reporter_name"`
	ReporterPhone      *string `json:"reporter_phone,omitempty"`
	BloodType          *string `json:"blood_type,omitempty"`
	Allergies          *string `json:"allergies,omitempty"`
	IncidentType       string  `json:"incident_type"`
	Status             string  `json:"status"`
	Latitude           float64 `json:"latitude"`
	Longitude          float64 `json:"longitude"`
	ReporterTrustLabel string  `json:"reporter_trust_label"`
	CreatedAt          string  `json:"created_at"`
	ResolvedAt         *string `json:"resolved_at,omitempty"`
}

type ResolveResponse struct {
	Resolved     bool   `json:"resolved"`
	XPEarned     int    `json:"xp_earned"`
	NewTotalXP   int    `json:"new_total_xp"`
	TotalRescues int    `json:"total_rescues"`
	RankUp       bool   `json:"rank_up"`
	NewRank      string `json:"new_rank,omitempty"`
}

// FalseAlarmResponse dikirim setelah mark-false-alarm berhasil.
type FalseAlarmResponse struct {
	MarkedFalseAlarm bool   `json:"marked_false_alarm"`
	StrikeCount      int    `json:"strike_count"`
	UserBanned       bool   `json:"user_banned"`
	Message          string `json:"message"`
}
