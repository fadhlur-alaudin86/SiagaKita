package agency

import (
	"fmt"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

type Repository struct {
	db *gorm.DB
}

func NewRepository(db *gorm.DB) *Repository {
	return &Repository{db: db}
}

// GetAgencyIDByUser gets the agency UUID mapped to an agency user account.
func (r *Repository) GetAgencyIDByUser(userID string) (string, error) {
	var agencyID string
	err := r.db.Table("agencies").Select("id").Where("account_id = ?", userID).Scan(&agencyID).Error
	if err != nil {
		return "", err
	}
	if agencyID == "" {
		return "", fmt.Errorf("data instansi tidak ditemukan untuk akun ini")
	}
	return agencyID, nil
}

// GetAgencyProfileByUser gets the full Agency model for the logged-in user.
func (r *Repository) GetAgencyProfileByUser(userID string) (*Agency, error) {
	var agency Agency
	err := r.db.Table("agencies").Where("account_id = ?", userID).First(&agency).Error
	if err != nil {
		return nil, fmt.Errorf("profil instansi tidak ditemukan: %w", err)
	}
	return &agency, nil
}

// CreatePersonnel creates a new agency_personnel account.
func (r *Repository) CreatePersonnel(req *CreatePersonnelRequest, agencyID string) error {
	hashed, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return fmt.Errorf("gagal mengenkripsi password: %w", err)
	}

	return r.db.Transaction(func(tx *gorm.DB) error {
		// 1. Cek email unik
		var emailCount int64
		if err := tx.Table("users").Where("email = ? AND deleted_at IS NULL", req.Email).Count(&emailCount).Error; err != nil {
			return err
		}
		if emailCount > 0 {
			return fmt.Errorf("email sudah digunakan")
		}

		// 2. Cek badge_number unik
		var badgeCount int64
		if err := tx.Table("agency_personnels").Where("badge_number = ?", req.BadgeNumber).Count(&badgeCount).Error; err != nil {
			return err
		}
		if badgeCount > 0 {
			return fmt.Errorf("nomor lencana (badge) sudah terdaftar")
		}

		// 3. Buat user (role: agency_personnel)
		type User struct {
			ID           string `gorm:"column:id;primaryKey;default:gen_random_uuid()"`
			Email        string `gorm:"column:email"`
			PasswordHash string `gorm:"column:password_hash"`
			Role         string `gorm:"column:role"`
		}
		newUser := User{
			Email:        req.Email,
			PasswordHash: string(hashed),
			Role:         "agency_personnel",
		}
		if err := tx.Table("users").Create(&newUser).Error; err != nil {
			return err
		}

		// 4. Buat agency_personnels entry
		type Personnel struct {
			UserID      string `gorm:"column:user_id;primaryKey"`
			AgencyID    string `gorm:"column:agency_id"`
			FullName    string `gorm:"column:full_name"`
			BadgeNumber string `gorm:"column:badge_number"`
			IsActive    bool   `gorm:"column:is_active;default:true"`
		}
		newPersonnel := Personnel{
			UserID:      newUser.ID,
			AgencyID:    agencyID,
			FullName:    req.FullName,
			BadgeNumber: req.BadgeNumber,
			IsActive:    true,
		}
		return tx.Table("agency_personnels").Create(&newPersonnel).Error
	})
}
