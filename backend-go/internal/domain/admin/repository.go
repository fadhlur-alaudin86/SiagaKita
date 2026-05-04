package admin

import (
	"fmt"
	"time"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// Repository handles all DB operations for the admin domain.
type Repository struct {
	db *gorm.DB
}

func NewRepository(db *gorm.DB) *Repository {
	return &Repository{db: db}
}

// ─── KYC Relawan ──────────────────────────────────────────────────────────────

// GetPendingKYC returns volunteers with at least one pending certification.
func (r *Repository) GetPendingKYC() ([]VolunteerKYC, error) {
	type row struct {
		UserID      string    `gorm:"column:user_id"`
		Email       string    `gorm:"column:email"`
		FullName    *string   `gorm:"column:full_name"`
		NIK         *string   `gorm:"column:nik"`
		SubmittedAt time.Time `gorm:"column:submitted_at"`
	}

	var rows []row
	err := r.db.Raw(`
		SELECT DISTINCT u.id AS user_id, u.email,
		       p.full_name, p.nik,
		       MIN(vc.created_at) AS submitted_at
		FROM users u
		JOIN user_profiles p ON p.user_id = u.id
		JOIN volunteer_certifications vc ON vc.user_id = u.id
		WHERE vc.status = 'pending'
		  AND u.deleted_at IS NULL
		GROUP BY u.id, u.email, p.full_name, p.nik
		ORDER BY submitted_at ASC
	`).Scan(&rows).Error
	if err != nil {
		return nil, err
	}

	result := make([]VolunteerKYC, 0, len(rows))
	for _, r2 := range rows {
		certs, err := r.getCertsForUser(r2.UserID, "pending")
		if err != nil {
			return nil, err
		}
		result = append(result, VolunteerKYC{
			UserID:      r2.UserID,
			FullName:    r2.FullName,
			Email:       r2.Email,
			NIK:         r2.NIK,
			Certs:       certs,
			SubmittedAt: r2.SubmittedAt,
		})
	}
	return result, nil
}

func (r *Repository) getCertsForUser(userID, status string) ([]KYCCert, error) {
	type certRow struct {
		ID              string    `gorm:"column:id"`
		CertificateType string    `gorm:"column:certificate_type"`
		DocumentURL     string    `gorm:"column:document_url"`
		ExpiresAt       *string   `gorm:"column:expires_at"`
		CreatedAt       time.Time `gorm:"column:created_at"`
	}
	var rows []certRow
	err := r.db.Raw(`
		SELECT id, certificate_type, document_url,
		       TO_CHAR(expires_at, 'DD-MM-YYYY') AS expires_at,
		       created_at
		FROM volunteer_certifications
		WHERE user_id = ? AND status = ?
	`, userID, status).Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	certs := make([]KYCCert, 0, len(rows))
	for _, c := range rows {
		certs = append(certs, KYCCert(c))
	}
	return certs, nil
}

// ApproveKYC sets all pending certs for a user to 'approved' and marks them verified.
func (r *Repository) ApproveKYC(userID, verifiedBy string) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Exec(`
			UPDATE volunteer_certifications
			SET status = 'approved', verified_by = ?
			WHERE user_id = ? AND status = 'pending'
		`, verifiedBy, userID).Error; err != nil {
			return err
		}
		return tx.Exec(`
			UPDATE user_profiles SET is_verified_volunteer = TRUE WHERE user_id = ?
		`, userID).Error
	})
}

// RejectKYC sets all pending certs for a user to 'rejected'.
func (r *Repository) RejectKYC(userID, verifiedBy, reason string) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		// Store reason in a future 'rejection_reason' column if needed.
		// For now we just mark rejected + log who did it.
		_ = reason // will be used when we add rejection_reason column
		return tx.Exec(`
			UPDATE volunteer_certifications
			SET status = 'rejected', verified_by = ?
			WHERE user_id = ? AND status = 'pending'
		`, verifiedBy, userID).Error
	})
}

// ─── User Management ──────────────────────────────────────────────────────────

// CreateAdmin creates a new user with 'admin' role and its corresponding admin_profiles.
func (r *Repository) CreateAdmin(req *CreateAdminRequest, superadminID string) error {
	hashed, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return fmt.Errorf("gagal mengenkripsi password: %w", err)
	}

	return r.db.Transaction(func(tx *gorm.DB) error {
		// 1. Check email
		var count int64
		if err := tx.Table("users").Where("email = ? AND deleted_at IS NULL", req.Email).Count(&count).Error; err != nil {
			return err
		}
		if count > 0 {
			return fmt.Errorf("email sudah digunakan")
		}

		// 2. Create user
		type User struct {
			ID           string `gorm:"column:id;primaryKey;default:gen_random_uuid()"`
			Email        string `gorm:"column:email"`
			PasswordHash string `gorm:"column:password_hash"`
			Role         string `gorm:"column:role"`
		}
		newUser := User{
			Email:        req.Email,
			PasswordHash: string(hashed),
			Role:         "admin",
		}
		if err := tx.Table("users").Create(&newUser).Error; err != nil {
			return err
		}

		// 3. Create admin_profiles
		type AdminProfile struct {
			UserID    string `gorm:"column:user_id;primaryKey"`
			FullName  string `gorm:"column:full_name"`
			CreatedBy string `gorm:"column:created_by"`
		}
		newProfile := AdminProfile{
			UserID:    newUser.ID,
			FullName:  req.FullName,
			CreatedBy: superadminID,
		}
		return tx.Table("admin_profiles").Create(&newProfile).Error
	})
}

// CreateAgency creates a new user with 'agency' role and its corresponding agencies entry.
func (r *Repository) CreateAgency(req *CreateAgencyRequest) error {
	hashed, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return fmt.Errorf("gagal mengenkripsi password: %w", err)
	}

	return r.db.Transaction(func(tx *gorm.DB) error {
		// 1. Check email
		var count int64
		if err := tx.Table("users").Where("email = ? AND deleted_at IS NULL", req.Email).Count(&count).Error; err != nil {
			return err
		}
		if count > 0 {
			return fmt.Errorf("email sudah digunakan")
		}

		// 2. Create user (role: agency)
		type User struct {
			ID           string `gorm:"column:id;primaryKey;default:gen_random_uuid()"`
			Email        string `gorm:"column:email"`
			PasswordHash string `gorm:"column:password_hash"`
			Role         string `gorm:"column:role"`
		}
		newUser := User{
			Email:        req.Email,
			PasswordHash: string(hashed),
			Role:         "agency",
		}
		if err := tx.Table("users").Create(&newUser).Error; err != nil {
			return err
		}

		// 3. Create agencies
		type Agency struct {
			ID            string   `gorm:"column:id;primaryKey;default:gen_random_uuid()"`
			Name          string   `gorm:"column:name"`
			Type          string   `gorm:"column:type"`
			CityCode      string   `gorm:"column:city_code"`
			HotlineNumber *string  `gorm:"column:hotline_number"`
			Latitude      *float64 `gorm:"column:latitude"`
			Longitude     *float64 `gorm:"column:longitude"`
			AccountID     string   `gorm:"column:account_id"`
		}
		newAgency := Agency{
			Name:          req.Name,
			Type:          req.Type,
			CityCode:      req.CityCode,
			HotlineNumber: req.HotlineNumber,
			Latitude:      req.Latitude,
			Longitude:     req.Longitude,
			AccountID:     newUser.ID,
		}
		return tx.Table("agencies").Create(&newAgency).Error
	})
}

// GetUsers returns all users with civilian/volunteer role (paginated).
func (r *Repository) GetUsers(filterBanned bool, filterHighStrike bool, search string) ([]AdminUserItem, error) {
	query := r.db.Raw(`
		SELECT u.id AS user_id, u.email, u.role, u.created_at,
		       p.full_name, p.phone_number,
		       p.is_email_verified, p.is_phone_verified,
		       p.sos_strike_count, p.is_sos_banned, p.banned_until
		FROM users u
		LEFT JOIN user_profiles p ON p.user_id = u.id
		WHERE u.deleted_at IS NULL
		  AND u.role IN ('civilian','volunteer')
		  AND (? = '' OR u.email ILIKE '%' || ? || '%' OR p.full_name ILIKE '%' || ? || '%')
		  AND (? = false OR p.is_sos_banned = true)
		  AND (? = false OR p.sos_strike_count >= 2)
		ORDER BY u.created_at DESC
	`, search, search, search, filterBanned, filterHighStrike)

	type row struct {
		UserID          string     `gorm:"column:user_id"`
		Email           string     `gorm:"column:email"`
		Role            string     `gorm:"column:role"`
		FullName        *string    `gorm:"column:full_name"`
		PhoneNumber     *string    `gorm:"column:phone_number"`
		IsEmailVerified bool       `gorm:"column:is_email_verified"`
		IsPhoneVerified bool       `gorm:"column:is_phone_verified"`
		SOSStrikeCount  int        `gorm:"column:sos_strike_count"`
		IsSOSBanned     bool       `gorm:"column:is_sos_banned"`
		BannedUntil     *time.Time `gorm:"column:banned_until"`
		CreatedAt       time.Time  `gorm:"column:created_at"`
	}
	var rows []row
	if err := query.Scan(&rows).Error; err != nil {
		return nil, err
	}

	items := make([]AdminUserItem, 0, len(rows))
	for _, r2 := range rows {
		items = append(items, AdminUserItem(r2))
	}
	return items, nil
}

// BanUser sets is_sos_banned = true in user_profiles.
func (r *Repository) BanUser(userID, reason string) error {
	_ = reason // bisa disimpan ke tabel audit di masa depan
	return r.db.Exec(`
		UPDATE user_profiles SET is_sos_banned = TRUE WHERE user_id = ?
	`, userID).Error
}

// UnbanUser sets is_sos_banned = false and clears banned_until.
func (r *Repository) UnbanUser(userID string) error {
	return r.db.Exec(`
		UPDATE user_profiles
		SET is_sos_banned = FALSE, banned_until = NULL
		WHERE user_id = ?
	`, userID).Error
}

// ResetStrike resets sos_strike_count = 0 dan unban.
func (r *Repository) ResetStrike(userID string) error {
	return r.db.Exec(`
		UPDATE user_profiles
		SET sos_strike_count = 0, is_sos_banned = FALSE, banned_until = NULL
		WHERE user_id = ?
	`, userID).Error
}

// ─── Ranks (Master Data) ──────────────────────────────────────────────────────

func (r *Repository) GetRanks() ([]MRank, error) {
	var ranks []MRank
	err := r.db.Order("min_exp ASC").Find(&ranks).Error
	return ranks, err
}

func (r *Repository) CreateRank(req *RankRequest) (*MRank, error) {
	rank := MRank{RankName: req.RankName, MinExp: req.MinExp, IconURL: req.IconURL}
	err := r.db.Create(&rank).Error
	return &rank, err
}

func (r *Repository) UpdateRank(id int, req *RankRequest) (*MRank, error) {
	var rank MRank
	if err := r.db.First(&rank, id).Error; err != nil {
		return nil, fmt.Errorf("rank tidak ditemukan")
	}
	rank.RankName = req.RankName
	rank.MinExp = req.MinExp
	rank.IconURL = req.IconURL
	return &rank, r.db.Save(&rank).Error
}

func (r *Repository) DeleteRank(id int) error {
	result := r.db.Delete(&MRank{}, id)
	if result.RowsAffected == 0 {
		return fmt.Errorf("rank tidak ditemukan")
	}
	return result.Error
}

// ─── Statistics ───────────────────────────────────────────────────────────────

func (r *Repository) GetStats() (*StatsResponse, error) {
	stats := &StatsResponse{
		ByType:   make(map[string]int64),
		ByStatus: make(map[string]int64),
	}

	// Total counts
	r.db.Raw(`SELECT COUNT(*) FROM incidents`).Scan(&stats.TotalSOS)
	r.db.Raw(`SELECT COUNT(*) FROM incidents WHERE status = 'resolved'`).Scan(&stats.TotalResolved)
	r.db.Raw(`SELECT COUNT(*) FROM incidents WHERE status = 'false_alarm'`).Scan(&stats.TotalFalseAlarm)
	r.db.Raw(`SELECT COUNT(*) FROM user_profiles WHERE is_verified_volunteer = true`).Scan(&stats.ActiveVolunteers)

	if stats.TotalSOS > 0 {
		stats.FalseAlarmRate = float64(stats.TotalFalseAlarm) / float64(stats.TotalSOS) * 100
	}

	// Avg response time (resolved_at - created_at in minutes)
	r.db.Raw(`
		SELECT COALESCE(AVG(EXTRACT(EPOCH FROM (resolved_at - created_at)) / 60), 0)
		FROM incidents
		WHERE status = 'resolved' AND resolved_at IS NOT NULL
	`).Scan(&stats.AvgResponseMinutes)

	// By type
	type kv struct {
		Key   string `gorm:"column:key"`
		Count int64  `gorm:"column:count"`
	}
	var byType []kv
	r.db.Raw(`
		SELECT incident_type AS key, COUNT(*) AS count
		FROM incidents GROUP BY incident_type
	`).Scan(&byType)
	for _, v := range byType {
		stats.ByType[v.Key] = v.Count
	}

	// By status
	var byStatus []kv
	r.db.Raw(`
		SELECT status AS key, COUNT(*) AS count
		FROM incidents GROUP BY status
	`).Scan(&byStatus)
	for _, v := range byStatus {
		stats.ByStatus[v.Key] = v.Count
	}

	// Monthly SOS (last 12 months)
	var monthly []struct {
		Month string `gorm:"column:month"`
		Count int64  `gorm:"column:count"`
	}
	r.db.Raw(`
		SELECT TO_CHAR(created_at, 'YYYY-MM') AS month, COUNT(*) AS count
		FROM incidents
		WHERE created_at >= NOW() - INTERVAL '12 months'
		GROUP BY month
		ORDER BY month ASC
	`).Scan(&monthly)
	for _, m := range monthly {
		stats.Monthly = append(stats.Monthly, MonthlyCount{Month: m.Month, Count: m.Count})
	}

	return stats, nil
}
