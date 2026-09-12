package user

import (
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

// buildProfileUpdateMap constructs the map of fields to update for a user profile.
func buildProfileUpdateMap(req *UpdateProfileRequest) (map[string]interface{}, error) {
	profileMap := map[string]interface{}{
		fieldUpdatedAt: time.Now(),
	}
	if req.FullName != nil {
		profileMap["full_name"] = *req.FullName
	}
	if req.NIK != nil {
		profileMap["nik"] = *req.NIK
	}
	if req.PhoneNumber != nil {
		profileMap["phone_number"] = *req.PhoneNumber
		profileMap["is_phone_verified"] = false
	}
	if req.BloodType != nil {
		profileMap["blood_type"] = *req.BloodType
	}
	if req.PlaceOfBirth != nil {
		profileMap["place_of_birth"] = *req.PlaceOfBirth
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
	if req.Domicile != nil {
		profileMap["domicile"] = *req.Domicile
	}
	if req.Bio != nil {
		profileMap["bio"] = *req.Bio
	}
	if req.DateOfBirth != nil {
		parsed, err := time.Parse("02-01-2006", *req.DateOfBirth)
		if err != nil {
			return nil, fmt.Errorf("format date_of_birth tidak valid, gunakan DD-MM-YYYY: %w", err)
		}
		profileMap["date_of_birth"] = parsed
	}
	return profileMap, nil
}

// replaceEmergencyContacts soft-deletes existing contacts and inserts new ones within the transaction.
func replaceEmergencyContacts(tx *gorm.DB, userID string, contacts []EmergencyContactInput) error {
	now := time.Now()
	if err := tx.Model(&EmergencyContact{}).Where("user_id = ? AND deleted_at IS NULL", userID).Update("deleted_at", now).Error; err != nil {
		return err
	}
	for _, c := range contacts {
		var relPtr *string
		if c.Relation != "" {
			normalized := NormalizeRelation(c.Relation)
			if normalized != "" {
				relPtr = &normalized
			}
		}
		contact := EmergencyContact{
			UserID:       userID,
			ContactName:  c.Name,
			ContactPhone: c.Phone,
			Relation:     relPtr,
		}
		if err := tx.Create(&contact).Error; err != nil {
			return err
		}
	}
	return nil
}

// UpdateProfile updates editable fields of user_profiles, replacing emergency contacts.
func (r *Repository) UpdateProfile(userID string, req *UpdateProfileRequest) error {
	profileMap, err := buildProfileUpdateMap(req)
	if err != nil {
		return err
	}

	return r.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Model(&UserProfile{}).Where("user_id = ?", userID).Updates(profileMap).Error; err != nil {
			return err
		}

		if req.EmergencyContacts != nil {
			return replaceEmergencyContacts(tx, userID, req.EmergencyContacts)
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
			PlaceOfBirth:      req.PlaceOfBirth,
			Allergies:         req.Allergies,
			MedicalConditions: req.MedicalConditions,
			HeightCm:          req.HeightCm,
			WeightKg:          req.WeightKg,
			Domicile:          req.Domicile,
			UpdatedAt:         time.Now(),
		}

		// NIK dan tanggal lahir hanya di-update jika disertakan
		profileMap := map[string]interface{}{
			"blood_type":         req.BloodType,
			"place_of_birth":     req.PlaceOfBirth,
			"allergies":          req.Allergies,
			"medical_conditions": req.MedicalConditions,
			"height_cm":          req.HeightCm,
			"weight_kg":          req.WeightKg,
			"domicile":           req.Domicile,
			fieldUpdatedAt:       time.Now(),
		}
		if req.PhoneNumber != nil {
			profileMap["phone_number"] = *req.PhoneNumber
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
			var relPtr *string
			if req.EmergencyRelation != nil && *req.EmergencyRelation != "" {
				normalized := NormalizeRelation(*req.EmergencyRelation)
				if normalized != "" {
					relPtr = &normalized
				}
			}
			contact := EmergencyContact{
				UserID:       userID,
				ContactName:  *req.EmergencyContactName,
				ContactPhone: *req.EmergencyContactPhone,
				Relation:     relPtr,
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
		resp.PlaceOfBirth = profile.PlaceOfBirth
		resp.MedicalConditions = profile.MedicalConditions
		resp.HeightCm = profile.HeightCm
		resp.WeightKg = profile.WeightKg
		resp.Domicile = profile.Domicile
		resp.Bio = profile.Bio

		if profile.DateOfBirth != nil {
			dob := profile.DateOfBirth.Format("02-01-2006")
			resp.DateOfBirth = &dob
		}
	}

	if reputation.UserID != "" {
		resp.VolunteerReputation = &reputation
	}

	// Tentukan volunteer_status dari is_verified_volunteer dan volunteer_certifications
	if profile != nil && profile.IsVerifiedVolunteer {
		resp.VolunteerStatus = string(KYCStatusApproved)
	} else {
		var pendingCount int64
		r.db.Model(&VolunteerCertification{}).
			Where("user_id = ? AND status = ?", userID, KYCStatusPending).
			Count(&pendingCount)
		if pendingCount > 0 {
			resp.VolunteerStatus = string(KYCStatusPending)
		} else {
			resp.VolunteerStatus = string(KYCStatusNone)
		}
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

// FindPersonnelByBadgeNumber retrieves an agency_personnels row by badge_number.
func (r *Repository) FindPersonnelByBadgeNumber(badge string) (*AgencyPersonnel, error) {
	var p AgencyPersonnel
	err := r.db.Where("badge_number = ?", badge).First(&p).Error
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
func (r *Repository) SubmitKYC(userID, nik, fullName, placeOfBirth, dateOfBirthStr, ktpURL, photoURL string) error {
	// Cek apakah NIK sudah digunakan oleh akun lain.
	var count int64
	if err := r.db.Model(&UserProfile{}).
		Where("nik = ? AND user_id != ?", nik, userID).
		Count(&count).Error; err != nil {
		return err
	}
	if count > 0 {
		return ErrNIKAlreadyUsed
	}

	updates := map[string]interface{}{
		"nik":                     nik,
		"full_name":               fullName,
		"place_of_birth":          placeOfBirth,
		"kyc_ktp_url":             ktpURL,
		"profile_photo_url":       photoURL,
		"nik_verification_status": KYCStatusPending,
		fieldUpdatedAt:            time.Now(),
	}

	if dateOfBirthStr != "" {
		parsed, err := time.Parse("02-01-2006", dateOfBirthStr)
		if err != nil {
			return fmt.Errorf("format date_of_birth tidak valid: %w", err)
		}
		updates["date_of_birth"] = parsed
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

// ─── Pendaftaran Relawan ──────────────────────────────────────────────────────

// SubmitVolunteerRegistration menyimpan sertifikat dan pengalaman relawan.
func (r *Repository) SubmitVolunteerRegistration(userID string, experience string, certs []map[string]string) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		// Update pengalaman relawan
		if err := tx.Exec(`
			UPDATE user_profiles
			SET volunteer_experience = ?, updated_at = NOW()
			WHERE user_id = ?
		`, experience, userID).Error; err != nil {
			return err
		}

		// Insert setiap sertifikat
		for _, cert := range certs {
			if err := tx.Exec(`
				INSERT INTO volunteer_certifications (user_id, certificate_type, document_url, status)
				VALUES (?, ?, ?, 'pending')
			`, userID, cert["type"], cert["url"]).Error; err != nil {
				return err
			}
		}

		return nil
	})
}

// ─── FCM Token Management ───────────────────────────────────────────────────

// UpdateFCMToken sets the user's FCM device token.
func (r *Repository) UpdateFCMToken(userID, token string) error {
	return r.db.Model(&UserProfile{}).Where("user_id = ?", userID).Update("fcm_token", token).Error
}

// ClearFCMToken resets the user's FCM token to NULL on logout.
func (r *Repository) ClearFCMToken(userID string) error {
	return r.db.Model(&UserProfile{}).Where("user_id = ?", userID).Update("fcm_token", gorm.Expr("NULL")).Error
}

// ClearStaleFCMTokens resets invalid/unregistered FCM tokens to NULL.
func (r *Repository) ClearStaleFCMTokens(tokens []string) error {
	if len(tokens) == 0 {
		return nil
	}
	return r.db.Model(&UserProfile{}).Where("fcm_token IN ?", tokens).Update("fcm_token", gorm.Expr("NULL")).Error
}

// FindVolunteerFCMTokensByIDs retrieves active FCM tokens for verified volunteers in userIDs.
func (r *Repository) FindVolunteerFCMTokensByIDs(userIDs []string, excludeUserID string) ([]string, error) {
	if len(userIDs) == 0 {
		return nil, nil
	}
	var tokens []string
	query := r.db.Model(&UserProfile{}).
		Where("user_id IN ? AND user_id != ? AND fcm_token IS NOT NULL AND fcm_token != '' AND is_verified_volunteer = true", userIDs, excludeUserID)
	err := query.Pluck("fcm_token", &tokens).Error
	return tokens, err
}

// FindAllVerifiedVolunteerFCMTokens returns active FCM tokens for verified volunteers up to limit.
func (r *Repository) FindAllVerifiedVolunteerFCMTokens(excludeUserID string, limit int) ([]string, error) {
	var tokens []string
	if limit <= 0 {
		limit = 100
	}
	query := r.db.Model(&UserProfile{}).
		Where("user_id != ? AND fcm_token IS NOT NULL AND fcm_token != '' AND is_verified_volunteer = true", excludeUserID).
		Limit(limit)
	err := query.Pluck("fcm_token", &tokens).Error
	return tokens, err
}

// FindNearbyAgencyPersonnelTokens retrieves active personnel FCM tokens for agencies within radiusKm of (lat, lon).
func (r *Repository) FindNearbyAgencyPersonnelTokens(lat, lon, radiusKm float64) ([]string, error) {
	var tokens []string
	haversineSQL := `
		SELECT u.fcm_token
		FROM agency_personnels ap
		JOIN agencies a ON ap.agency_id = a.id
		JOIN user_profiles u ON ap.user_id = u.user_id
		WHERE u.fcm_token IS NOT NULL 
		  AND u.fcm_token != ''
		  AND ap.is_active = true
		  AND a.latitude IS NOT NULL 
		  AND a.longitude IS NOT NULL
		  AND (6371 * acos(
				LEAST(1.0, GREATEST(-1.0,
					cos(radians(?)) * cos(radians(a.latitude)) *
					cos(radians(a.longitude) - radians(?)) +
					sin(radians(?)) * sin(radians(a.latitude))
				))
		  )) <= ?`
	err := r.db.Raw(haversineSQL, lat, lon, lat, radiusKm).Scan(&tokens).Error
	return tokens, err
}

// FindUserFCMToken retrieves the active FCM token for a single user.
func (r *Repository) FindUserFCMToken(userID string) (string, error) {
	var token string
	err := r.db.Model(&UserProfile{}).
		Where("user_id = ? AND fcm_token IS NOT NULL AND fcm_token != ''", userID).
		Pluck("fcm_token", &token).Error
	return token, err
}
