package admin

import "time"

// ─── Response DTOs ────────────────────────────────────────────────────────────

// VolunteerKYC adalah data relawan yang menunggu verifikasi KYC.
type VolunteerKYC struct {
	UserID              string    `json:"user_id"`
	FullName            *string   `json:"full_name"`
	Email               string    `json:"email"`
	NIK                 *string   `json:"nik,omitempty"`
	VolunteerExperience *string   `json:"volunteer_experience,omitempty"`
	Certs               []KYCCert `json:"certifications"`
	SubmittedAt         time.Time `json:"submitted_at"`
}

type KYCCert struct {
	ID              string    `json:"id"`
	CertificateType string    `json:"certificate_type"`
	DocumentURL     string    `json:"document_url"`
	ExpiresAt       *string   `json:"expires_at,omitempty"`
	CreatedAt       time.Time `json:"created_at"`
}

// WargaKYCItem adalah data warga yang menunggu verifikasi NIK (KYC Warga).
type WargaKYCItem struct {
	UserID                string    `json:"user_id"`
	FullName              *string   `json:"full_name"`
	Email                 string    `json:"email"`
	NIK                   *string   `json:"nik"`
	KYCKtpURL             *string   `json:"kyc_ktp_url"`
	ProfilePhotoURL       *string   `json:"profile_photo_url"`
	NIKVerificationStatus string    `json:"nik_verification_status"`
	SubmittedAt           time.Time `json:"submitted_at"`
}

// AdminUserItem adalah baris tabel manajemen pengguna.
type AdminUserItem struct {
	UserID                string     `json:"user_id"`
	Email                 string     `json:"email"`
	Role                  string     `json:"role"`
	FullName              *string    `json:"full_name,omitempty"`
	PhoneNumber           *string    `json:"phone_number,omitempty"`
	NIK                   *string    `json:"nik,omitempty"`
	IsEmailVerified       bool       `json:"is_email_verified"`
	IsPhoneVerified       bool       `json:"is_phone_verified"`
	NIKVerificationStatus string     `json:"nik_verification_status"`
	SOSStrikeCount        int        `json:"sos_strike_count"` // Dihitung dari incidents status false_alarm
	IsSOSBanned           bool       `json:"is_sos_banned"`
	BannedUntil           *time.Time `json:"banned_until,omitempty"`
	LastActiveAt          *time.Time `json:"last_active_at,omitempty"`
	CreatedAt             time.Time  `json:"created_at"`
}

// UserDetailResponse adalah detail lengkap aktivitas satu pengguna warga.
type UserDetailResponse struct {
	UserID                string          `json:"user_id"`
	Email                 string          `json:"email"`
	Role                  string          `json:"role"`
	FullName              *string         `json:"full_name,omitempty"`
	PhoneNumber           *string         `json:"phone_number,omitempty"`
	NIK                   *string         `json:"nik,omitempty"`
	IsEmailVerified       bool            `json:"is_email_verified"`
	IsPhoneVerified       bool            `json:"is_phone_verified"`
	NIKVerificationStatus string          `json:"nik_verification_status"`
	KYCKtpURL             *string         `json:"kyc_ktp_url,omitempty"`
	ProfilePhotoURL       *string         `json:"profile_photo_url,omitempty"`
	DateOfBirth           *string         `json:"date_of_birth,omitempty"`
	BloodType             *string         `json:"blood_type,omitempty"`
	Allergies             *string         `json:"allergies,omitempty"`
	Domicile              *string         `json:"domicile,omitempty"`
	SOSStrikeCount        int             `json:"sos_strike_count"`
	IsSOSBanned           bool            `json:"is_sos_banned"`
	LastActiveAt          *time.Time      `json:"last_active_at,omitempty"`
	CreatedAt             time.Time       `json:"created_at"`
	SOSHistory            []SOSHistoryItem  `json:"sos_history"`
	ReportHistory         []ReportHistoryItem `json:"report_history"`
}

// SOSHistoryItem adalah satu baris riwayat SOS seorang pengguna.
type SOSHistoryItem struct {
	ID           string     `json:"id"`
	IncidentType string     `json:"incident_type"`
	Status       string     `json:"status"`
	Latitude     float64    `json:"latitude"`
	Longitude    float64    `json:"longitude"`
	CreatedAt    time.Time  `json:"created_at"`
	CompletedAt   *time.Time `json:"completed_at,omitempty"`
}

// ReportHistoryItem adalah satu baris riwayat laporan biasa seorang pengguna.
type ReportHistoryItem struct {
	ID           string    `json:"id"`
	IncidentType string    `json:"incident_type"`
	Status       string    `json:"status"`
	Description  *string   `json:"description,omitempty"`
	CreatedAt    time.Time `json:"created_at"`
}

// AgencyItem adalah data instansi yang terdaftar.
type AgencyItem struct {
	AgencyID      string   `json:"agency_id"`
	AccountID     string   `json:"account_id"`
	Email         string   `json:"email"`
	Name          string   `json:"name"`
	Type          string   `json:"type"`
	CityCode      string   `json:"city_code"`
	HotlineNumber *string  `json:"hotline_number,omitempty"`
	Latitude      *float64 `json:"latitude,omitempty"`
	Longitude     *float64 `json:"longitude,omitempty"`
	CreatedAt     time.Time `json:"created_at"`
}

// AdminItem adalah data admin yang terdaftar (superadmin only).
type AdminItem struct {
	UserID    string    `json:"user_id"`
	Email     string    `json:"email"`
	Role      string    `json:"role"`
	FullName  *string   `json:"full_name,omitempty"`
	CreatedBy *string   `json:"created_by,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}

// StatsResponse adalah respons endpoint GET /admin/stats.
type StatsResponse struct {
	TotalSOS           int64            `json:"total_sos"`
	TotalResolved      int64            `json:"total_resolved"`
	TotalFalseAlarm    int64            `json:"total_false_alarm"`
	ActiveVolunteers   int64            `json:"active_volunteers"`
	FalseAlarmRate     float64          `json:"false_alarm_rate"`
	AvgResponseMinutes float64          `json:"avg_response_minutes"`
	ByType             map[string]int64 `json:"by_type"`
	ByStatus           map[string]int64 `json:"by_status"`
	Monthly            []MonthlyCount   `json:"monthly"`
}

type MonthlyCount struct {
	Month string `json:"month"` // Format: "2026-04"
	Count int64  `json:"count"`
}

// ─── Request DTOs ─────────────────────────────────────────────────────────────

type RejectKYCRequest struct {
	Reason string `json:"reason"`
}

type CreateAdminRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
	FullName string `json:"full_name"`
}

type CreateAgencyRequest struct {
	Email         string   `json:"email"`
	Password      string   `json:"password"`
	Name          string   `json:"name"`
	Type          string   `json:"type"`
	CityCode      string   `json:"city_code"`
	HotlineNumber *string  `json:"hotline_number,omitempty"`
	Latitude      *float64 `json:"latitude,omitempty"`
	Longitude     *float64 `json:"longitude,omitempty"`
}

type BanUserRequest struct {
	Reason string `json:"reason"`
}

type RankRequest struct {
	RankName string `json:"rank_name"`
	MinExp   int    `json:"min_exp"`
	IconURL  string `json:"icon_url,omitempty"`
}

// MRank master data rank.
type MRank struct {
	ID       int    `gorm:"primaryKey;autoIncrement" json:"id"`
	RankName string `gorm:"not null" json:"rank_name"`
	MinExp   int    `gorm:"not null" json:"min_exp"`
	IconURL  string `json:"icon_url,omitempty"`
}

func (MRank) TableName() string { return "m_ranks" }

type MBadge struct {
	ID          string `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	BadgeName   string `gorm:"not null" json:"badge_name"`
	Description string `json:"description"`
	IconURL     string `json:"icon_url,omitempty"`
}

func (MBadge) TableName() string { return "m_badges" }

type BadgeRequest struct {
	BadgeName   string `json:"badge_name"`
	Description string `json:"description"`
	IconURL     string `json:"icon_url,omitempty"`
}
