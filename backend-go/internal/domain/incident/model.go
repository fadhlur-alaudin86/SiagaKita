package incident

import (
	"encoding/json"
	"time"

	"github.com/lib/pq"
)

// StringSlice adalah []string yang selalu di-marshal sebagai JSON array (tidak pernah null).
// Digunakan di response DTOs sebagai pengganti pq.StringArray agar kompatibel dengan
// Sonic JSON encoder yang digunakan Fiber.
type StringSlice []string

func (s StringSlice) MarshalJSON() ([]byte, error) {
	if s == nil {
		return []byte("[]"), nil
	}
	type plain []string
	return json.Marshal(plain(s))
}

// parsePhotoPathsJSON mengkonversi JSON text dari array_to_json()::text ke []string.
func parsePhotoPathsJSON(raw string) []string {
	if raw == "" || raw == "null" || raw == "[]" {
		return []string{}
	}
	var result []string
	if err := json.Unmarshal([]byte(raw), &result); err != nil {
		return []string{}
	}
	return result
}

func (s *StringSlice) Scan(src interface{}) error {
	if src == nil {
		*s = StringSlice{}
		return nil
	}
	// Utama: src adalah JSON text dari array_to_json()::text
	switch v := src.(type) {
	case string:
		if v == "" || v == "null" {
			*s = StringSlice{}
			return nil
		}
		var result []string
		if err := json.Unmarshal([]byte(v), &result); err != nil {
			*s = StringSlice{}
			return nil
		}
		*s = StringSlice(result)
		return nil
	case []byte:
		if len(v) == 0 {
			*s = StringSlice{}
			return nil
		}
		var result []string
		if err := json.Unmarshal(v, &result); err != nil {
			*s = StringSlice{}
			return nil
		}
		*s = StringSlice(result)
		return nil
	case []string:
		*s = StringSlice(v)
		return nil
	case []interface{}:
		result := make(StringSlice, 0, len(v))
		for _, item := range v {
			if str, ok := item.(string); ok {
				result = append(result, str)
			}
		}
		*s = result
		return nil
	default:
		// Fallback: lib/pq format
		var arr pq.StringArray
		if err := arr.Scan(src); err != nil {
			*s = StringSlice{}
			return nil
		}
		*s = StringSlice(arr)
		return nil
	}
}

// Nilai-nilai valid untuk incident_status:
// 'grace_period' | 'broadcasting' | 'handled' | 'resolved' | 'false_alarm' | 'canceled'

// ─── DB Models ────────────────────────────────────────────────────────────────

// Incident merepresentasikan SOS darurat dari masyarakat (Jalur A).
type Incident struct {
	ID                 string         `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	ReporterID         string         `gorm:"type:uuid;not null" json:"reporter_id"`
	IncidentType       string         `gorm:"default:'unknown'" json:"incident_type"` // incident_category enum
	Latitude           float64        `gorm:"not null" json:"latitude"`
	Longitude          float64        `gorm:"not null" json:"longitude"`
	Status             string         `gorm:"default:'grace_period'" json:"status"`
	HandledByAgencyID  *string        `gorm:"type:uuid" json:"handled_by_agency_id,omitempty"`
	AgencyStatus       string         `gorm:"default:'pending'" json:"agency_status"`
	UrgencyLevel       string         `gorm:"default:'critical'" json:"urgency_level"`
	ReporterTrustLabel string         `gorm:"default:'standard'" json:"reporter_trust_label"` // 'verified'|'standard'|'unverified'
	AddressDetail      *string        `json:"address_detail,omitempty"`
	PhotoPaths         pq.StringArray `gorm:"type:text[]" json:"photo_paths"` // Bukti foto kamera depan (pasca broadcasting)
	AudioPath          *string        `json:"audio_path,omitempty"`           // Bukti audio 5 detik (pasca broadcasting)
	CreatedAt          time.Time      `json:"created_at"`
	UpdatedAt          time.Time      `json:"updated_at"`
	CompletedAt        *time.Time     `json:"completed_at,omitempty"`
}

// IncidentReport merepresentasikan laporan warga non-darurat (Jalur B).
type IncidentReport struct {
	ID            string         `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	ReporterID    string         `gorm:"type:uuid;not null" json:"reporter_id"`
	IncidentType  string         `gorm:"not null" json:"incident_type"`
	UrgencyLevel  *int           `json:"urgency_level,omitempty"` // 0=ringan, 1=sedang, 2=kritis
	Latitude      float64        `gorm:"not null" json:"latitude"`
	Longitude     float64        `gorm:"not null" json:"longitude"`
	AddressDetail *string        `json:"address_detail,omitempty"`
	Description   *string        `json:"description,omitempty"`
	PhotoPaths    pq.StringArray `gorm:"type:text[]" json:"photo_paths"`
	AudioPath     *string        `json:"audio_path,omitempty"`
	Status        string         `gorm:"default:'sent'" json:"status"`
	CreatedAt     time.Time      `json:"created_at"`
	UpdatedAt     time.Time      `json:"updated_at"`
	CompletedAt   *time.Time     `json:"completed_at,omitempty"`
}

// SOSStrike adalah audit log setiap kali admin menandai false alarm.
type SOSStrike struct {
	ID         string    `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	UserID     string    `gorm:"type:uuid;not null" json:"user_id"`
	IncidentID *string   `gorm:"type:uuid" json:"incident_id,omitempty"`
	Reason     string    `json:"reason"`
	GivenBy    *string   `gorm:"type:uuid;column:marked_by" json:"given_by,omitempty"` // admin/agency UUID
	CreatedAt  time.Time `json:"created_at"`
}

// IncidentResponse adalah respons relawan/instansi terhadap incident.
type IncidentResponse struct {
	ID            string     `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	IncidentID    string     `gorm:"type:uuid;not null" json:"incident_id"`
	ResponderID   string     `gorm:"type:uuid;not null" json:"responder_id"`
	Status        string     `gorm:"type:public.response_status;default:on_scene" json:"status"`
	AcceptedAt    time.Time  `json:"accepted_at"`
	CompletedAt   *time.Time `json:"completed_at,omitempty"`
	ProofPhotoURL *string    `json:"proof_photo_url,omitempty"`
	Latitude      *float64   `gorm:"column:latitude" json:"latitude,omitempty"`
	Longitude     *float64   `gorm:"column:longitude" json:"longitude,omitempty"`
	AddressDetail *string    `gorm:"column:address_detail" json:"address_detail,omitempty"`
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

// TriggerSOSRequest - Jalur A: hanya GPS wajib, tipe selalu mulai 'unknown'.
type TriggerSOSRequest struct {
	Latitude      float64 `json:"latitude"`
	Longitude     float64 `json:"longitude"`
	AddressDetail string  `json:"address_detail"`
}

// UploadSOSEvidenceRequest - dikirim SETELAH masuk fase broadcasting.
// Berisi foto kamera depan (1 gambar) dan audio 5 detik sebagai bukti situasi.
// Dikirim sebagai multipart/form-data.
type UploadSOSEvidenceRequest struct {
	IncidentID string `form:"incident_id"` // validasi bahwa incident milik reporter
}

// UpdateResponseLocationRequest - dikirim relawan saat menangani SOS.
type UpdateResponseLocationRequest struct {
	Latitude      float64 `json:"latitude"`
	Longitude     float64 `json:"longitude"`
	AddressDetail *string `json:"address_detail,omitempty"`
}

// ActiveResponseDTO - misi aktif relawan (incident_response berstatus on_scene).
type ActiveResponseDTO struct {
	ResponseID    string  `json:"response_id"`
	IncidentID    string  `json:"incident_id"`
	IncidentType  string  `json:"incident_type"`
	Status        string  `json:"status"`
	Latitude      float64 `json:"reporter_latitude"`
	Longitude     float64 `json:"reporter_longitude"`
	AddressDetail *string `json:"address_detail,omitempty"`
	AcceptedAt    string  `json:"accepted_at"`
}

// UpdateTypeRequest - dikirim dari grace period UI saat user memilih tipe.
type UpdateTypeRequest struct {
	IncidentType string `json:"incident_type"` // 'medical'|'fire'|'crime'|'rescue'|'general'
}

// UpdateLocationRequest - dikirim tiap 1 menit selama SOS aktif.
type UpdateLocationRequest struct {
	IncidentID string  `json:"incident_id"`
	Latitude   float64 `json:"latitude"`
	Longitude  float64 `json:"longitude"`
}

// MarkFalseAlarmRequest - admin menandai insiden sebagai false alarm.
type MarkFalseAlarmRequest struct {
	Reason string `json:"reason"`
}

// CreateReportRequest - Jalur B: laporan warga non-darurat (multipart/form-data).
type CreateReportRequest struct {
	IncidentType  string  `form:"incident_type"` // wajib
	Latitude      float64 `form:"latitude"`
	Longitude     float64 `form:"longitude"`
	AddressDetail string  `form:"address_detail"`
	Description   string  `form:"description"`
}

// ─── Response DTOs ─────────────────────────────────────────────────────────────

// TriggerSOSResponse dikirim ke Flutter setelah SOS berhasil dibuat.
type TriggerSOSResponse struct {
	IncidentID string `json:"incident_id"`
	Status     string `json:"status"`
	Message    string `json:"message"`
}

type VolunteerLocation struct {
	Name      string  `json:"name"`
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

// ActiveIncidentResponse - data SOS aktif milik reporter.
type ActiveIncidentResponse struct {
	IncidentID              string              `json:"incident_id"`
	Status                  string              `json:"status"`
	IncidentType            string              `json:"incident_type"`
	Latitude                float64             `json:"latitude"`
	Longitude               float64             `json:"longitude"`
	CreatedAt               string              `json:"created_at"`
	ReporterTrustLabel      string              `json:"reporter_trust_label"`
	AgencyStatus            *string             `json:"agency_status,omitempty"`
	HandledByAgencyID       *string             `json:"handled_by_agency_id,omitempty"`
	AgencyName              *string             `json:"agency_name,omitempty"`
	VolunteerResponseStatus *string             `json:"volunteer_response_status,omitempty"`
	VolunteerNames          []string            `json:"volunteer_names,omitempty"`
	VolunteerLocations      []VolunteerLocation `json:"volunteer_locations,omitempty"`
}

// AllActiveIncidentResponse - data SOS aktif LENGKAP untuk console desktop (JOIN ke users & profiles).
type AllActiveIncidentResponse struct {
	ID                       string      `json:"id"`
	ReporterID               string      `json:"reporter_id"`
	ReporterName             string      `json:"reporter_name"`
	ReporterPhone            *string     `json:"reporter_phone,omitempty"`
	BloodType                *string     `json:"blood_type,omitempty"`
	Allergies                *string     `json:"allergies,omitempty"`
	IncidentType             string      `json:"incident_type"`
	Status                   string      `json:"status"`
	Latitude                 float64     `json:"latitude"`
	Longitude                float64     `json:"longitude"`
	AddressDetail            *string     `json:"address_detail,omitempty"`
	ReporterTrustLabel       string      `json:"reporter_trust_label"`
	AgencyStatus             *string     `json:"agency_status,omitempty"`
	HandledByAgencyID        *string     `json:"handled_by_agency_id,omitempty"`
	VolunteerResponseStatus  *string     `json:"volunteer_response_status,omitempty"`
	ResponderID              *string     `json:"responder_id,omitempty"`
	ResponderName            *string     `json:"responder_name,omitempty"`
	CreatedAt                time.Time   `json:"created_at"`
	UpdatedAt                time.Time   `json:"updated_at"`
	CompletedAt              *time.Time  `json:"completed_at,omitempty"`
	IsNikVerified            bool        `json:"is_nik_verified"`
	IsPhoneVerified          bool        `json:"is_phone_verified"`
	ReporterDob              *string     `json:"reporter_dob,omitempty"`
	ReporterDomicile         *string     `json:"reporter_domicile,omitempty"`
	ReporterBio              *string     `json:"reporter_bio,omitempty"`
	ReporterEmergencyContact *string     `json:"reporter_emergency_contact,omitempty"`
	PhotoPaths               StringSlice `gorm:"-" json:"photo_paths"`
	PhotoPathsRaw            string      `gorm:"column:photo_paths" json:"-"`
	AudioPath                *string     `json:"audio_path,omitempty"`
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

// NearbyIncidentResponse - SOS aktif dalam radius tertentu dari posisi relawan.
type NearbyIncidentResponse struct {
	ID                 string      `json:"id"`
	IncidentType       string      `json:"incident_type"`
	Status             string      `json:"status"`
	Latitude           float64     `json:"latitude"`
	Longitude          float64     `json:"longitude"`
	AddressDetail      *string     `json:"address_detail,omitempty"`
	ReporterTrustLabel string      `json:"reporter_trust_label"`
	CreatedAt          string      `json:"created_at"`
	DistanceKm         float64     `json:"distance_km"`
	PhotoPaths         StringSlice `gorm:"-" json:"photo_paths"`
	PhotoPathsRaw      string      `gorm:"column:photo_paths" json:"-"`
	AudioPath          *string     `json:"audio_path,omitempty"`
}

// AcceptSOSResponse - response setelah relawan menerima SOS.
type AcceptSOSResponse struct {
	Accepted   bool   `json:"accepted"`
	IncidentID string `json:"incident_id"`
	Status     string `json:"status"`
	Message    string `json:"message"`
}

type AgencyReviewRequest struct {
	Approve bool   `json:"approve"` // true = terima, false = tolak
	Reason  string `json:"reason,omitempty"`
}

type MissionHistoryResponse struct {
	ID             string  `json:"id"`
	IncidentType   string  `json:"incident_type"`
	Status         string  `json:"status"`          // Status global
	ResponseStatus string  `json:"response_status"` // Status relawan
	AddressDetail  *string `json:"address_detail,omitempty"`
	AcceptedAt     string  `json:"accepted_at"`
	XPEarned       int     `json:"xp_earned,omitempty"` // Jika ada XP historis
}

// IncidentReportResponse - data lengkap laporan (Jalur B) dengan nama pelapor.
type IncidentReportResponse struct {
	ID            string      `json:"id"`
	ReporterID    string      `json:"reporter_id"`
	ReporterName  string      `json:"reporter_name"`
	ReporterPhone *string     `json:"reporter_phone,omitempty"`
	IncidentType  string      `json:"incident_type"`
	UrgencyLevel  *int        `json:"urgency_level,omitempty"` // 0=ringan, 1=sedang, 2=kritis
	Latitude      float64     `json:"latitude"`
	Longitude     float64     `json:"longitude"`
	AddressDetail *string     `json:"address_detail,omitempty"`
	Description   *string     `json:"description,omitempty"`
	PhotoPaths    StringSlice `gorm:"-" json:"photo_paths"`
	PhotoPathsRaw string      `gorm:"column:photo_paths" json:"-"`
	AudioPath     *string     `json:"audio_path,omitempty"`
	Status        string      `json:"status"`
	CreatedAt     time.Time   `json:"created_at"`
	UpdatedAt     time.Time   `json:"updated_at"`
	CompletedAt   *time.Time  `json:"completed_at,omitempty"`
}
