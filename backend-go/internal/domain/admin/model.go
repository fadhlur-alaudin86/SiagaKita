package admin

import "time"

// ─── Response DTOs ────────────────────────────────────────────────────────────

// VolunteerKYC adalah data relawan yang menunggu verifikasi KYC.
type VolunteerKYC struct {
	UserID      string     `json:"user_id"`
	FullName    *string    `json:"full_name"`
	Email       string     `json:"email"`
	NIK         *string    `json:"nik,omitempty"`
	Certs       []KYCCert  `json:"certifications"`
	SubmittedAt time.Time  `json:"submitted_at"`
}

type KYCCert struct {
	ID              string    `json:"id"`
	CertificateType string    `json:"certificate_type"`
	DocumentURL     string    `json:"document_url"`
	ExpiresAt       *string   `json:"expires_at,omitempty"`
	CreatedAt       time.Time `json:"created_at"`
}

// AdminUserItem adalah baris tabel manajemen pengguna.
type AdminUserItem struct {
	UserID         string     `json:"user_id"`
	Email          string     `json:"email"`
	Role           string     `json:"role"`
	FullName       *string    `json:"full_name,omitempty"`
	PhoneNumber    *string    `json:"phone_number,omitempty"`
	IsEmailVerified bool      `json:"is_email_verified"`
	IsPhoneVerified bool      `json:"is_phone_verified"`
	SOSStrikeCount int        `json:"sos_strike_count"`
	IsSOSBanned    bool       `json:"is_sos_banned"`
	BannedUntil    *time.Time `json:"banned_until,omitempty"`
	CreatedAt      time.Time  `json:"created_at"`
}

// StatsResponse adalah respons endpoint GET /admin/stats.
type StatsResponse struct {
	TotalSOS            int64              `json:"total_sos"`
	TotalResolved       int64              `json:"total_resolved"`
	TotalFalseAlarm     int64              `json:"total_false_alarm"`
	ActiveVolunteers    int64              `json:"active_volunteers"`
	FalseAlarmRate      float64            `json:"false_alarm_rate"`
	AvgResponseMinutes  float64            `json:"avg_response_minutes"`
	ByType              map[string]int64   `json:"by_type"`
	ByStatus            map[string]int64   `json:"by_status"`
	Monthly             []MonthlyCount     `json:"monthly"`
}

type MonthlyCount struct {
	Month string `json:"month"` // Format: "2026-04"
	Count int64  `json:"count"`
}

// ─── Request DTOs ─────────────────────────────────────────────────────────────

type RejectKYCRequest struct {
	Reason string `json:"reason"`
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
