package user

import (
	"errors"
	"fmt"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// Repository handles all database operations for the user domain.
type Repository struct {
	db *gorm.DB
}

// NewRepository creates a new user Repository.
func NewRepository(db *gorm.DB) *Repository {
	return &Repository{db: db}
}

// ─── User (auth) ──────────────────────────────────────────────────────────────

// CreateUser inserts a new users row.
func (r *Repository) CreateUser(user *User) error {
	return r.db.Create(user).Error
}

// FindByEmail retrieves a non-deleted user by email.
func (r *Repository) FindByEmail(email string) (*User, error) {
	var u User
	err := r.db.Where("email = ? AND deleted_at IS NULL", email).First(&u).Error
	return &u, err
}

// FindByID retrieves a non-deleted user by primary key.
func (r *Repository) FindByID(id string) (*User, error) {
	var u User
	err := r.db.Where("id = ? AND deleted_at IS NULL", id).First(&u).Error
	return &u, err
}

// DeleteUserByEmail hard-deletes a user by email (rollback on OTP send failure).
func (r *Repository) DeleteUserByEmail(email string) error {
	return r.db.Unscoped().Where("email = ?", email).Delete(&User{}).Error
}

// UpdatePassword updates the user's password hash.
func (r *Repository) UpdatePassword(userID, newHash string) error {
	return r.db.Model(&User{}).Where("id = ?", userID).Update("password_hash", newHash).Error
}

// ─── UserProfile (civilian/volunteer) ────────────────────────────────────────

// CreateProfile inserts a new user_profiles row.
func (r *Repository) CreateProfile(p *UserProfile) error {
	return r.db.Create(p).Error
}

// CreateUserWithProfile inserts users + user_profiles dalam SATU transaksi.
// Jika salah satu gagal, keduanya di-rollback atomik.
func (r *Repository) CreateUserWithProfile(user *User, profile *UserProfile) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(user).Error; err != nil {
			return err
		}
		profile.UserID = user.ID // pastikan FK terisi dari ID yang baru di-generate
		return tx.Create(profile).Error
	})
}

// FindProfile retrieves the user_profiles row for a given userID.
func (r *Repository) FindProfile(userID string) (*UserProfile, error) {
	var p UserProfile
	err := r.db.Where("user_id = ?", userID).First(&p).Error
	return &p, err
}

// SetEmailVerified marks is_email_verified = true in user_profiles.
func (r *Repository) SetEmailVerified(userID string) error {
	return r.db.Model(&UserProfile{}).
		Where("user_id = ?", userID).
		Update("is_email_verified", true).Error
}

// SetPhoneVerified marks is_phone_verified = true in user_profiles.
func (r *Repository) SetPhoneVerified(userID string) error {
	return r.db.Model(&UserProfile{}).
		Where("user_id = ?", userID).
		Update("is_phone_verified", true).Error
}

// UpdatePhoneNumber saves a new phone number (resets is_phone_verified).
func (r *Repository) UpdatePhoneNumber(userID, phone string) error {
	return r.db.Model(&UserProfile{}).
		Where("user_id = ?", userID).
		Updates(map[string]interface{}{
			"phone_number":      phone,
			"is_phone_verified": false,
		}).Error
}

// UpdateProfile updates editable fields of user_profiles, replacing emergency contacts.
func (r *Repository) UpdateProfile(userID string, req *UpdateProfileRequest) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		profileMap := map[string]interface{}{
			"updated_at": time.Now(),
		}
		if req.FullName != nil {
			profileMap["full_name"] = *req.FullName
		}
		if req.BloodType != nil {
			profileMap["blood_type"] = *req.BloodType
		}
		if req.Allergies != nil {
			profileMap["allergies"] = *req.Allergies
		}
		if req.MedicalConditions != nil {
			profileMap["medical_conditions"] = *req.MedicalConditions
		}
		if req.HeightCm != nil {
			profileMap["height_cm"] = *req.HeightCm
		}
		if req.WeightKg != nil {
			profileMap["weight_kg"] = *req.WeightKg
		}
		if req.Alamat != nil {
			profileMap["alamat"] = *req.Alamat
		}
		if req.Bio != nil {
			profileMap["bio"] = *req.Bio
		}
		if req.DateOfBirth != nil {
			parsed, err := time.Parse("02-01-2006", *req.DateOfBirth)
			if err != nil {
				return fmt.Errorf("format date_of_birth tidak valid, gunakan DD-MM-YYYY: %w", err)
			}
			profileMap["date_of_birth"] = parsed
		}

		if err := tx.Model(&UserProfile{}).Where("user_id = ?", userID).Updates(profileMap).Error; err != nil {
			return err
		}

		// Replace emergency contacts: soft-delete existing, then insert new
		if req.EmergencyContacts != nil {
			now := time.Now()
			if err := tx.Model(&EmergencyContact{}).Where("user_id = ? AND deleted_at IS NULL", userID).Update("deleted_at", now).Error; err != nil {
				return err
			}
			for _, c := range req.EmergencyContacts {
				relation := c.Relation
				contact := EmergencyContact{
					UserID:       userID,
					ContactName:  c.Name,
					ContactPhone: c.Phone,
					Relation:     &relation,
				}
				if err := tx.Create(&contact).Error; err != nil {
					return err
				}
			}
		}

		return nil
	})
}

// SaveBiodata updates user_profiles and upserts emergency contact.
func (r *Repository) SaveBiodata(userID string, req *BiodataRequest) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		// 1. Upsert user_profiles
		profile := UserProfile{
			UserID:            userID,
			BloodType:         req.BloodType,
			Allergies:         req.Allergies,
			MedicalConditions: req.MedicalConditions,
			HeightCm:          req.HeightCm,
			WeightKg:          req.WeightKg,
			Alamat:            req.Alamat,
			UpdatedAt:         time.Now(),
		}

		// NIK dan tanggal lahir hanya di-update jika disertakan
		profileMap := map[string]interface{}{
			"blood_type":         req.BloodType,
			"allergies":          req.Allergies,
			"medical_conditions": req.MedicalConditions,
			"height_cm":          req.HeightCm,
			"weight_kg":          req.WeightKg,
			"alamat":             req.Alamat,
			"updated_at":         time.Now(),
		}
		if req.NIK != nil {
			profileMap["nik"] = *req.NIK
		}
		if req.DateOfBirth != nil {
			parsed, err := time.Parse("02-01-2006", *req.DateOfBirth)
			if err != nil {
				return fmt.Errorf("format date_of_birth tidak valid, gunakan DD-MM-YYYY: %w", err)
			}
			profileMap["date_of_birth"] = parsed
			profile.DateOfBirth = &parsed
		}

		if err := tx.Clauses(clause.OnConflict{
			Columns:   []clause.Column{{Name: "user_id"}},
			DoUpdates: clause.Assignments(profileMap),
		}).Create(&profile).Error; err != nil {
			return err
		}

		// 2. Insert emergency contact (jika disertakan)
		if req.EmergencyContactName != nil && req.EmergencyContactPhone != nil {
			contact := EmergencyContact{
				UserID:       userID,
				ContactName:  *req.EmergencyContactName,
				ContactPhone: *req.EmergencyContactPhone,
				Relation:     req.EmergencyRelation,
			}
			if err := tx.Create(&contact).Error; err != nil {
				return err
			}
		}

		return nil
	})
}

// GetProfile fetches the combined civilian/volunteer profile.
func (r *Repository) GetProfile(userID string) (*ProfileResponse, error) {
	user, err := r.FindByID(userID)
	if err != nil {
		return nil, err
	}

	profile, _ := r.FindProfile(userID)

	var contacts []EmergencyContact
	r.db.Where("user_id = ? AND deleted_at IS NULL", userID).Find(&contacts)

	var reputation VolunteerReputation
	r.db.Where("user_id = ?", userID).First(&reputation)

	resp := &ProfileResponse{
		ID:                user.ID,
		Email:             user.Email,
		Role:              user.Role,
		EmergencyContacts: contacts,
	}

	if profile != nil && profile.UserID != "" {
		resp.FullName = profile.FullName
		resp.NIK = profile.NIK
		resp.PhoneNumber = profile.PhoneNumber
		resp.IsEmailVerified = profile.IsEmailVerified
		resp.IsPhoneVerified = profile.IsPhoneVerified
		resp.IsVerifiedVolunteer = profile.IsVerifiedVolunteer
		resp.NIKVerificationStatus = profile.NIKVerificationStatus
		resp.SOSStrikeCount = profile.SOSStrikeCount
		resp.IsSOSBanned = profile.IsSOSBanned
		resp.BloodType = profile.BloodType
		resp.Allergies = profile.Allergies
		resp.MedicalConditions = profile.MedicalConditions
		resp.HeightCm = profile.HeightCm
		resp.WeightKg = profile.WeightKg
		resp.Alamat = profile.Alamat
		resp.Bio = profile.Bio

		if profile.DateOfBirth != nil {
			dob := profile.DateOfBirth.Format("02-01-2006")
			resp.DateOfBirth = &dob
		}
	}

	if reputation.UserID != "" {
		resp.VolunteerReputation = &reputation
	}

	return resp, nil
}

// ─── AdminProfile ─────────────────────────────────────────────────────────────

// CreateAdminProfile inserts a new admin_profiles row.
func (r *Repository) CreateAdminProfile(p *AdminProfile) error {
	return r.db.Create(p).Error
}

// ─── AgencyPersonnel ──────────────────────────────────────────────────────────

// CreateAgencyPersonnel inserts a new agency_personnels row.
func (r *Repository) CreateAgencyPersonnel(p *AgencyPersonnel) error {
	return r.db.Create(p).Error
}

// FindPersonnelByUserID retrieves an agency_personnels row by user_id.
func (r *Repository) FindPersonnelByUserID(userID string) (*AgencyPersonnel, error) {
	var p AgencyPersonnel
	err := r.db.Where("user_id = ?", userID).First(&p).Error
	return &p, err
}

// FindPersonnelByAgencyID retrieves all personnels belonging to an agency.
func (r *Repository) FindPersonnelByAgencyID(agencyID string) ([]AgencyPersonnel, error) {
	var ps []AgencyPersonnel
	err := r.db.Where("agency_id = ?", agencyID).Find(&ps).Error
	return ps, err
}

// ─── KYC Warga ────────────────────────────────────────────────────────────────

// SubmitKYC menyimpan pengajuan verifikasi NIK & selfie (foto profil) warga.
func (r *Repository) SubmitKYC(userID, nik, fullName, ktpURL, photoURL string) error {
	// Cek apakah NIK sudah digunakan oleh akun lain.
	var count int64
	if err := r.db.Model(&UserProfile{}).
		Where("nik = ? AND user_id != ?", nik, userID).
		Count(&count).Error; err != nil {
		return err
	}
	if count > 0 {
		return errors.New("NIK_ALREADY_USED")
	}

	updates := map[string]interface{}{
		"nik":                      nik,
		"full_name":                fullName,
		"kyc_ktp_url":              ktpURL,
		"profile_photo_url":        photoURL,
		"nik_verification_status":  "pending",
		"updated_at":               time.Now(),
	}
	return r.db.Model(&UserProfile{}).Where("user_id = ?", userID).Updates(updates).Error
}

// GetKYCStatus mengambil status verifikasi NIK warga.
func (r *Repository) GetKYCStatus(userID string) (*UserProfile, error) {
	var p UserProfile
	err := r.db.Select("user_id, nik, nik_verification_status, profile_photo_url").
		Where("user_id = ?", userID).First(&p).Error
	return &p, err
}
