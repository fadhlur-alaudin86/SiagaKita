package user

import "time"

// ─── DB Models ────────────────────────────────────────────────────────────────

// User adalah auth gateway - hanya menyimpan kredensial dan role.
// Profil lengkap ada di user_profiles (civilian/volunteer) atau
// admin_profiles (admin) atau agency_personnels (agency_personnel).
type User struct {
	ID           string     `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	Email        string     `gorm:"uniqueIndex;not null" json:"email"`
	PasswordHash string     `gorm:"not null" json:"-"`
	Role         string     `gorm:"not null;default:'civilian'" json:"role"`
	CreatedAt    time.Time  `json:"created_at"`
	DeletedAt    *time.Time `gorm:"index" json:"-"`
}

func (User) TableName() string { return "users" }

// UserProfile menyimpan data lengkap akun civilian dan volunteer.
// Row ini dibuat secara transaksional bersamaan dengan pembuatan User.
type UserProfile struct {
	UserID              string     `gorm:"type:uuid;primaryKey" json:"user_id"`
	FullName            *string    `json:"full_name,omitempty"`
	NIK                 *string    `gorm:"uniqueIndex" json:"nik,omitempty"`
	PlaceOfBirth        *string    `json:"place_of_birth,omitempty"`
	DateOfBirth         *time.Time `json:"date_of_birth,omitempty"`
	PhoneNumber         *string    `gorm:"uniqueIndex" json:"phone_number,omitempty"`
	IsEmailVerified     bool       `gorm:"default:false" json:"is_email_verified"`
	IsPhoneVerified     bool       `gorm:"default:false" json:"is_phone_verified"`
	IsVerifiedVolunteer bool       `gorm:"default:false" json:"is_verified_volunteer"`
	SOSStrikeCount      int        `gorm:"default:0" json:"sos_strike_count"`
	IsSOSBanned         bool       `gorm:"default:false" json:"is_sos_banned"`
	BannedUntil         *time.Time `json:"banned_until,omitempty"`
	BloodType           *string    `json:"blood_type,omitempty"`
	Allergies           *string    `json:"allergies,omitempty"`
	MedicalConditions   *string    `json:"medical_conditions,omitempty"`
	HeightCm            *int       `json:"height_cm,omitempty"`
	WeightKg            *int       `json:"weight_kg,omitempty"`
	Domicile            *string    `json:"domicile,omitempty"`
	Bio                 *string    `json:"bio,omitempty"`
	// KYC Warga (NIK Verification)
	KYCKtpURL *string `gorm:"column:kyc_ktp_url" json:"kyc_ktp_url,omitempty"`
	// Selfie dari proses KYC sekaligus digunakan sebagai foto profil warga.
	ProfilePhotoURL       *string   `gorm:"column:profile_photo_url" json:"profile_photo_url,omitempty"`
	NIKVerificationStatus string    `gorm:"default:'none'" json:"nik_verification_status"`
	VolunteerExperience   *string   `gorm:"column:volunteer_experience" json:"volunteer_experience,omitempty"`
	UpdatedAt             time.Time `json:"updated_at"`
}

func (UserProfile) TableName() string { return "user_profiles" }

// AdminProfile menyimpan nama dan metadata akun admin.
// Dibuat saat superadmin membuat akun admin baru.
type AdminProfile struct {
	UserID    string    `gorm:"type:uuid;primaryKey" json:"user_id"`
	FullName  *string   `json:"full_name,omitempty"`
	CreatedBy *string   `gorm:"type:uuid" json:"created_by,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (AdminProfile) TableName() string { return "admin_profiles" }

// AgencyPersonnel menyimpan data personel instansi.
type AgencyPersonnel struct {
	UserID      string    `gorm:"type:uuid;primaryKey" json:"user_id"`
	AgencyID    string    `gorm:"type:uuid;not null" json:"agency_id"`
	FullName    string    `gorm:"not null" json:"full_name"`
	BadgeNumber string    `gorm:"uniqueIndex;not null" json:"badge_number"`
	IsActive    bool      `gorm:"default:true" json:"is_active"`
	CreatedAt   time.Time `json:"created_at"`
}

func (AgencyPersonnel) TableName() string { return "agency_personnels" }

// EmergencyContact menyimpan kontak darurat milik civilian/volunteer.
type EmergencyContact struct {
	ID           string     `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	UserID       string     `gorm:"type:uuid;not null;index" json:"user_id"`
	ContactName  string     `json:"contact_name"`
	ContactPhone string     `json:"contact_phone"`
	Relation     *string    `json:"relation,omitempty"`
	CreatedAt    time.Time  `json:"created_at"`
	DeletedAt    *time.Time `gorm:"index" json:"-"`
}

func (EmergencyContact) TableName() string { return "emergency_contacts" }

// VolunteerReputation menyimpan XP dan rank relawan.
type VolunteerReputation struct {
	UserID       string    `gorm:"type:uuid;primaryKey" json:"user_id"`
	ExpPoints    int       `gorm:"default:0" json:"exp_points"`
	RankID       *int      `json:"rank_id,omitempty"`
	TotalRescues int       `gorm:"default:0" json:"total_rescues"`
	UpdatedAt    time.Time `json:"updated_at"`
}

func (VolunteerReputation) TableName() string { return "volunteer_reputation" }

// VolunteerCertification menyimpan dokumen sertifikat relawan.
type VolunteerCertification struct {
	ID              string     `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	UserID          string     `gorm:"type:uuid;not null" json:"user_id"`
	CertificateType string     `gorm:"not null" json:"certificate_type"`
	DocumentURL     string     `gorm:"not null" json:"document_url"`
	Status          string     `gorm:"default:'pending'" json:"status"`
	VerifiedBy      *string    `gorm:"type:uuid" json:"verified_by,omitempty"`
	ExpiresAt       *time.Time `json:"expires_at,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
}

func (VolunteerCertification) TableName() string { return "volunteer_certifications" }

// ─── Request DTOs ──────────────────────────────────────────────────────────────

// RegisterRequest untuk pendaftaran civilian/volunteer via mobile.
type RegisterRequest struct {
	FullName string `json:"full_name"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

// LoginRequest untuk semua login endpoint.
type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

// CreateAdminRequest untuk pembuatan akun admin oleh superadmin.
type CreateAdminRequest struct {
	Email    string  `json:"email"`
	Password string  `json:"password"`
	FullName *string `json:"full_name,omitempty"`
}

// CreateAgencyRequest untuk pembuatan akun agency oleh admin.
type CreateAgencyRequest struct {
	Email         string `json:"email"`
	Password      string `json:"password"`
	AgencyName    string `json:"agency_name"`
	AgencyType    string `json:"agency_type"` // police|fire|medical|sar
	CityCode      string `json:"city_code"`
	HotlineNumber string `json:"hotline_number,omitempty"`
}

// CreatePersonnelRequest untuk pembuatan akun agency_personnel oleh agency.
type CreatePersonnelRequest struct {
	Email       string `json:"email"`
	Password    string `json:"password"`
	FullName    string `json:"full_name"`
	BadgeNumber string `json:"badge_number"`
}

// BiodataRequest untuk update profil civilian/volunteer.
type BiodataRequest struct {
	NIK                   *string `json:"nik"`
	PhoneNumber           *string `json:"phone_number"`
	PlaceOfBirth          *string `json:"place_of_birth"`
	DateOfBirth           *string `json:"date_of_birth"` // Format: DD-MM-YYYY
	BloodType             *string `json:"blood_type"`
	Allergies             *string `json:"allergies"`
	MedicalConditions     *string `json:"medical_conditions"`
	HeightCm              *int    `json:"height_cm"`
	WeightKg              *int    `json:"weight_kg"`
	Domicile              *string `json:"domicile"`
	EmergencyContactName  *string `json:"emergency_contact_name"`
	EmergencyContactPhone *string `json:"emergency_contact_phone"`
	EmergencyRelation     *string `json:"emergency_relation"`
}

type VerifyEmailOTPRequest struct {
	Email   string `json:"email"`
	OTPCode string `json:"otp_code"`
}

type PhoneUpdateRequest struct {
	PhoneNumber string `json:"phone_number"`
}

type VerifyPhoneRequest struct {
	PhoneNumber string `json:"phone_number"`
	OTPCode     string `json:"otp_code"`
}

// ─── Response DTOs ─────────────────────────────────────────────────────────────

type AuthResponse struct {
	AccessToken  string   `json:"access_token"`
	RefreshToken string   `json:"refresh_token"`
	User         UserInfo `json:"user"`
}

// UserInfo adalah payload ringkas yang disertakan dalam response login/register.
// FullName diisi dari tabel profil yang sesuai dengan role.
type UserInfo struct {
	ID       string  `json:"id"`
	Email    string  `json:"email"`
	Role     string  `json:"role"`
	FullName *string `json:"full_name,omitempty"`
}

// ProfileResponse untuk GET /users/profile (civilian/volunteer).
type ProfileResponse struct {
	ID                    string               `json:"id"`
	Email                 string               `json:"email"`
	Role                  string               `json:"role"`
	FullName              *string              `json:"full_name,omitempty"`
	NIK                   *string              `json:"nik,omitempty"`
	PlaceOfBirth          *string              `json:"place_of_birth,omitempty"`
	DateOfBirth           *string              `json:"date_of_birth,omitempty"`
	PhoneNumber           *string              `json:"phone_number,omitempty"`
	IsEmailVerified       bool                 `json:"is_email_verified"`
	IsPhoneVerified       bool                 `json:"is_phone_verified"`
	IsVerifiedVolunteer   bool                 `json:"is_verified_volunteer"`
	NIKVerificationStatus string               `json:"nik_verification_status"`
	SOSStrikeCount        int                  `json:"sos_strike_count"`
	IsSOSBanned           bool                 `json:"is_sos_banned"`
	BloodType             *string              `json:"blood_type,omitempty"`
	Allergies             *string              `json:"allergies,omitempty"`
	MedicalConditions     *string              `json:"medical_conditions,omitempty"`
	HeightCm              *int                 `json:"height_cm,omitempty"`
	WeightKg              *int                 `json:"weight_kg,omitempty"`
	Domicile              *string              `json:"domicile,omitempty"`
	Bio                   *string              `json:"bio,omitempty"`
	VolunteerExperience   *string              `json:"volunteer_experience,omitempty"`
	VolunteerStatus       string               `json:"volunteer_status"` // 'none' | 'pending' | 'approved'
	EmergencyContacts     []EmergencyContact   `json:"emergency_contacts"`
	VolunteerReputation   *VolunteerReputation `json:"volunteer_reputation,omitempty"`
}

// UpdateProfileRequest untuk PUT /users/profile (civilian/volunteer).
type UpdateProfileRequest struct {
	FullName          *string                 `json:"full_name"`
	NIK               *string                 `json:"nik"`
	PhoneNumber       *string                 `json:"phone_number"`
	PlaceOfBirth      *string                 `json:"place_of_birth"`
	DateOfBirth       *string                 `json:"date_of_birth"` // Format: DD-MM-YYYY
	BloodType         *string                 `json:"blood_type"`
	Allergies         *string                 `json:"allergies"`
	MedicalConditions *string                 `json:"medical_conditions"`
	HeightCm          *int                    `json:"height_cm"`
	WeightKg          *int                    `json:"weight_kg"`
	Domicile          *string                 `json:"domicile"`
	Bio               *string                 `json:"bio"`
	EmergencyContacts []EmergencyContactInput `json:"emergency_contacts"`
}

// EmergencyContactInput untuk update kontak darurat.
type EmergencyContactInput struct {
	Name     string `json:"name"`
	Phone    string `json:"phone"`
	Relation string `json:"relation"`
}

// ─── DTOs for Password Reset & OTP Resend ─────────────────────────────────────

type ForgotPasswordRequest struct {
	Email string `json:"email"`
}

type ResetPasswordRequest struct {
	Email       string `json:"email"`
	OTP         string `json:"otp"`
	NewPassword string `json:"new_password"`
}

type ResendOTPRequest struct {
	Email   string `json:"email"`
	Context string `json:"context"` // "register", "login", "forgot_password"
}

// ─── KYC Warga (Civilian Identity Verification) ────────────────────────────────

// KYCStatus adalah status verifikasi identitas NIK warga.
// Nilainya disimpan di user_profiles sebagai nik_verification_status.
type KYCStatus string

const (
	KYCStatusNone     KYCStatus = "none"
	KYCStatusPending  KYCStatus = "pending"
	KYCStatusApproved KYCStatus = "approved"
	KYCStatusRejected KYCStatus = "rejected"
)

// SubmitKYCRequest adalah body untuk POST /users/kyc.
// Diterima sebagai multipart/form-data karena menyertakan foto KTP dan selfie warga.
// Selfie digunakan sekaligus sebagai foto profil di halaman profil warga.
type SubmitKYCRequest struct {
	NIK          string `form:"nik"` // 16 digit NIK KTP
	FullName     string `form:"full_name"`
	PlaceOfBirth string `form:"place_of_birth"`
	DateOfBirth  string `form:"date_of_birth"`
}

// KYCStatusResponse adalah respons GET /users/kyc/status.
type KYCStatusResponse struct {
	Status          KYCStatus `json:"status"`
	NIK             *string   `json:"nik,omitempty"`
	ProfilePhotoURL *string   `json:"profile_photo_url,omitempty"`
	Message         string    `json:"message"`
}

// RegisterVolunteerRequest adalah request form data untuk pendaftaran relawan.
type RegisterVolunteerRequest struct {
	Specializations []string `form:"specializations"` // Akan diurai sebagai array dari form-data
	Experience      string   `form:"experience"`
}
