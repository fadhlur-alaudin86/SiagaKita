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
		UserID              string    `gorm:"column:user_id"`
		Email               string    `gorm:"column:email"`
		FullName            *string   `gorm:"column:full_name"`
		PhoneNumber         *string   `gorm:"column:phone_number"`
		NIK                 *string   `gorm:"column:nik"`
		NIKPhotoURL         *string   `gorm:"column:nik_photo_url"`
		VolunteerExperience *string   `gorm:"column:volunteer_experience"`
		SubmittedAt         time.Time `gorm:"column:submitted_at"`
	}

	var rows []row
	err := r.db.Raw(`
		SELECT DISTINCT u.id AS user_id, u.email,
		       p.full_name, p.phone_number, p.nik, p.kyc_ktp_url AS nik_photo_url,
		       p.volunteer_experience,
		       MIN(vc.created_at) AS submitted_at
		FROM users u
		JOIN user_profiles p ON p.user_id = u.id
		JOIN volunteer_certifications vc ON vc.user_id = u.id
		WHERE vc.status = 'pending'
		  AND u.deleted_at IS NULL
		GROUP BY u.id, u.email, p.full_name, p.phone_number, p.nik, p.kyc_ktp_url, p.volunteer_experience
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
			UserID:              r2.UserID,
			FullName:            r2.FullName,
			Email:               r2.Email,
			PhoneNumber:         r2.PhoneNumber,
			NIK:                 r2.NIK,
			NIKPhotoURL:         r2.NIKPhotoURL,
			VolunteerExperience: r2.VolunteerExperience,
			Certs:               certs,
			KYCStatus:           "pending",
			SubmittedAt:         r2.SubmittedAt,
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

// ApproveKYC sets all pending certs for a user to 'approved', marks them verified,
// and upgrades their role from 'civilian' to 'volunteer'.
func (r *Repository) ApproveKYC(userID, verifiedBy string) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		// 1. Cek apakah ada sertifikat pending untuk user ini
		var count int64
		if err := tx.Table("volunteer_certifications").
			Where("user_id = ? AND status = 'pending'", userID).
			Count(&count).Error; err != nil {
			return err
		}
		if count == 0 {
			return gorm.ErrRecordNotFound
		}

		// 2. Approve semua sertifikat pending
		if err := tx.Exec(`
			UPDATE volunteer_certifications
			SET status = 'approved', verified_by = ?
			WHERE user_id = ? AND status = 'pending'
		`, verifiedBy, userID).Error; err != nil {
			return err
		}
		// 3. Tandai profil sebagai relawan terverifikasi
		if err := tx.Exec(`
			UPDATE user_profiles SET is_verified_volunteer = TRUE WHERE user_id = ?
		`, userID).Error; err != nil {
			return err
		}
		// 4. Upgrade role: civilian → volunteer (guard agar tidak overwrite role lain)
		if err := tx.Exec(`
			UPDATE users SET role = 'volunteer' WHERE id = ? AND role = 'civilian'
		`, userID).Error; err != nil {
			return err
		}
		// 5. Inisialisasi baris volunteer_reputation jika belum ada
		return tx.Exec(`
			INSERT INTO volunteer_reputation (user_id, exp_points, rank_id, total_rescues)
			VALUES (?, 0, 1, 0)
			ON CONFLICT (user_id) DO NOTHING
		`, userID).Error
	})
}

// RejectKYC sets all pending certs for a user to 'rejected'.
func (r *Repository) RejectKYC(userID, verifiedBy, reason string) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		// 1. Cek apakah ada sertifikat pending untuk user ini
		var count int64
		if err := tx.Table("volunteer_certifications").
			Where("user_id = ? AND status = 'pending'", userID).
			Count(&count).Error; err != nil {
			return err
		}
		if count == 0 {
			return gorm.ErrRecordNotFound
		}

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

// GetUsers returns all users with civilian/volunteer role, supporting role, banned, strike, and search filters.
// Strike dihitung secara real-time dari jumlah incidents berstatus false_alarm.
func (r *Repository) GetUsers(filterBanned bool, filterHighStrike bool, search string, role string) ([]AdminUserItem, error) {
	var items []AdminUserItem
	err := r.db.Raw(`
		SELECT u.id AS user_id, u.email, u.role, u.created_at, u.last_active_at,
		       p.full_name, p.phone_number, p.nik,
		       p.is_email_verified, p.is_phone_verified,
		       COALESCE(p.nik_verification_status, 'none') AS nik_verification_status,
		       COALESCE((
		           SELECT COUNT(*) FROM incidents i
		           WHERE i.reporter_id = u.id AND i.status = 'false_alarm'
		       ), 0) AS sos_strike_count,
		       p.is_sos_banned, p.banned_until
		FROM users u
		LEFT JOIN user_profiles p ON p.user_id = u.id
		WHERE u.deleted_at IS NULL
		  AND u.role IN ('civilian','volunteer')
		  AND (? = '' OR u.role = ?)
		  AND (? = '' OR u.email ILIKE '%' || ? || '%' OR p.full_name ILIKE '%' || ? || '%' OR p.nik ILIKE '%' || ? || '%')
		  AND (? = false OR p.is_sos_banned = true)
		  AND (? = false OR (
		           SELECT COUNT(*) FROM incidents i2
		           WHERE i2.reporter_id = u.id AND i2.status = 'false_alarm'
		       ) >= 2)
		ORDER BY u.created_at DESC
	`, role, role, search, search, search, search, filterBanned, filterHighStrike).Scan(&items).Error
	if err != nil {
		return nil, err
	}
	return items, nil
}

// GetUserDetail mengambil detail lengkap seorang pengguna warga termasuk riwayat SOS dan laporan.
func (r *Repository) GetUserDetail(userID string) (*UserDetailResponse, error) {
	type baseRow struct {
		UserID                string     `gorm:"column:user_id"`
		Email                 string     `gorm:"column:email"`
		Role                  string     `gorm:"column:role"`
		FullName              *string    `gorm:"column:full_name"`
		PhoneNumber           *string    `gorm:"column:phone_number"`
		NIK                   *string    `gorm:"column:nik"`
		IsEmailVerified       bool       `gorm:"column:is_email_verified"`
		IsPhoneVerified       bool       `gorm:"column:is_phone_verified"`
		NIKVerificationStatus string     `gorm:"column:nik_verification_status"`
		KYCKtpURL             *string    `gorm:"column:kyc_ktp_url"`
		ProfilePhotoURL       *string    `gorm:"column:profile_photo_url"`
		DateOfBirth           *string    `gorm:"column:date_of_birth"`
		BloodType             *string    `gorm:"column:blood_type"`
		Allergies             *string    `gorm:"column:allergies"`
		Domicile              *string    `gorm:"column:domicile"`
		IsSOSBanned           bool       `gorm:"column:is_sos_banned"`
		BannedUntil           *time.Time `gorm:"column:banned_until"`
		LastActiveAt          *time.Time `gorm:"column:last_active_at"`
		CreatedAt             time.Time  `gorm:"column:created_at"`
		SOSStrikeCount        int        `gorm:"column:sos_strike_count"`
	}
	var base baseRow
	err := r.db.Raw(`
		SELECT u.id AS user_id, u.email, u.role, u.created_at, u.last_active_at,
		       p.full_name, p.phone_number, p.nik,
		       p.is_email_verified, p.is_phone_verified,
		       COALESCE(p.nik_verification_status, 'none') AS nik_verification_status,
		       p.kyc_ktp_url, p.profile_photo_url,
		       TO_CHAR(p.date_of_birth, 'DD-MM-YYYY') AS date_of_birth,
		       p.blood_type::text, p.allergies, p.domicile,
		       p.is_sos_banned,
		       COALESCE((
		           SELECT COUNT(*) FROM incidents i
		           WHERE i.reporter_id = u.id AND i.status = 'false_alarm'
		       ), 0) AS sos_strike_count
		FROM users u
		LEFT JOIN user_profiles p ON p.user_id = u.id
		WHERE u.id = ? AND u.deleted_at IS NULL
	`, userID).Scan(&base).Error
	if err != nil {
		return nil, err
	}
	if base.UserID == "" {
		return nil, fmt.Errorf("pengguna tidak ditemukan")
	}

	// Riwayat SOS
	var sosHistory []SOSHistoryItem
	r.db.Raw(`
		SELECT id, incident_type, status, latitude, longitude, created_at, completed_at
		FROM incidents WHERE reporter_id = ? ORDER BY created_at DESC
	`, userID).Scan(&sosHistory)

	// Riwayat Laporan
	var reportHistory []ReportHistoryItem
	r.db.Raw(`
		SELECT id, incident_type, status, description, created_at
		FROM incident_reports WHERE reporter_id = ? ORDER BY created_at DESC
	`, userID).Scan(&reportHistory)

	return &UserDetailResponse{
		UserID:                base.UserID,
		Email:                 base.Email,
		Role:                  base.Role,
		FullName:              base.FullName,
		PhoneNumber:           base.PhoneNumber,
		NIK:                   base.NIK,
		IsEmailVerified:       base.IsEmailVerified,
		IsPhoneVerified:       base.IsPhoneVerified,
		NIKVerificationStatus: base.NIKVerificationStatus,
		KYCKtpURL:             base.KYCKtpURL,
		ProfilePhotoURL:       base.ProfilePhotoURL,
		DateOfBirth:           base.DateOfBirth,
		BloodType:             base.BloodType,
		Allergies:             base.Allergies,
		Domicile:              base.Domicile,
		SOSStrikeCount:        base.SOSStrikeCount,
		IsSOSBanned:           base.IsSOSBanned,
		LastActiveAt:          base.LastActiveAt,
		CreatedAt:             base.CreatedAt,
		SOSHistory:            sosHistory,
		ReportHistory:         reportHistory,
	}, nil
}

// ─── KYC Warga (NIK Verification) ─────────────────────────────────────────────

// GetPendingWargaKYC mengembalikan daftar warga yang NIK-nya menunggu verifikasi.
func (r *Repository) GetPendingWargaKYC() ([]WargaKYCItem, error) {
	var rows []WargaKYCItem
	err := r.db.Raw(`
		SELECT u.id AS user_id, u.email,
		       p.full_name, p.nik,
		       p.kyc_ktp_url, p.profile_photo_url,
		       p.nik_verification_status,
		       p.updated_at AS submitted_at
		FROM users u
		JOIN user_profiles p ON p.user_id = u.id
		WHERE p.nik_verification_status = 'pending'
		  AND u.deleted_at IS NULL
		ORDER BY p.updated_at ASC
	`).Scan(&rows).Error
	return rows, err
}

// ApproveWargaKYC menyetujui verifikasi NIK warga.
func (r *Repository) ApproveWargaKYC(userID string) error {
	return r.db.Exec(`
		UPDATE user_profiles
		SET nik_verification_status = 'approved', updated_at = NOW()
		WHERE user_id = ? AND nik_verification_status = 'pending'
	`, userID).Error
}

// RejectWargaKYC menolak verifikasi NIK warga.
func (r *Repository) RejectWargaKYC(userID string) error {
	return r.db.Exec(`
		UPDATE user_profiles
		SET nik_verification_status = 'rejected', updated_at = NOW()
		WHERE user_id = ? AND nik_verification_status = 'pending'
	`, userID).Error
}

// ─── Agency & Admin Listings ──────────────────────────────────────────────────

// GetAgencies mengembalikan daftar seluruh instansi yang terdaftar.
func (r *Repository) GetAgencies() ([]AgencyItem, error) {
	var rows []AgencyItem
	err := r.db.Raw(`
		SELECT a.id AS agency_id, a.account_id, u.email,
		       a.name, a.type, a.city_code,
		       a.hotline_number, a.latitude, a.longitude,
		       u.created_at
		FROM agencies a
		JOIN users u ON u.id = a.account_id
		WHERE u.deleted_at IS NULL
		ORDER BY u.created_at DESC
	`).Scan(&rows).Error
	return rows, err
}

// GetAdmins mengembalikan daftar seluruh admin yang terdaftar (untuk superadmin).
func (r *Repository) GetAdmins() ([]AdminItem, error) {
	var rows []AdminItem
	err := r.db.Raw(`
		SELECT u.id AS user_id, u.email, u.role,
		       ap.full_name, ap.created_by, u.created_at
		FROM users u
		LEFT JOIN admin_profiles ap ON ap.user_id = u.id
		WHERE u.role IN ('admin', 'superadmin') AND u.deleted_at IS NULL
		ORDER BY u.role DESC, u.created_at DESC
	`).Scan(&rows).Error
	return rows, err
}

// BanUser sets is_sos_banned = true in user_profiles, sets banned_until if days > 0, and records audit in sos_strikes.
func (r *Repository) BanUser(userID string, req *BanUserRequest, callerID string) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		var bannedUntil *time.Time
		if req.Days > 0 {
			until := time.Now().AddDate(0, 0, req.Days)
			bannedUntil = &until
		}

		res := tx.Exec(`
			UPDATE user_profiles
			SET is_sos_banned = TRUE, banned_until = ?
			WHERE user_id = ?
		`, bannedUntil, userID)
		if res.Error != nil {
			return res.Error
		}
		if res.RowsAffected == 0 {
			return gorm.ErrRecordNotFound
		}

		reason := req.Reason
		if reason == "" {
			reason = "Diblokir oleh admin"
		}
		if req.Days > 0 {
			reason = fmt.Sprintf("%s (Durasi: %d hari)", reason, req.Days)
		}

		return tx.Exec(`
			INSERT INTO sos_strikes (id, user_id, incident_id, reason, marked_by, created_at)
			VALUES (gen_random_uuid(), ?, NULL, ?, ?, NOW())
		`, userID, reason, callerID).Error
	})
}

// UnbanUser sets is_sos_banned = false and clears banned_until, recording audit in sos_strikes.
func (r *Repository) UnbanUser(userID string, callerID string) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		res := tx.Exec(`
			UPDATE user_profiles
			SET is_sos_banned = FALSE, banned_until = NULL
			WHERE user_id = ?
		`, userID)
		if res.Error != nil {
			return res.Error
		}
		if res.RowsAffected == 0 {
			return gorm.ErrRecordNotFound
		}

		return tx.Exec(`
			INSERT INTO sos_strikes (id, user_id, incident_id, reason, marked_by, created_at)
			VALUES (gen_random_uuid(), ?, NULL, 'Ban dicabut oleh admin', ?, NOW())
		`, userID, callerID).Error
	})
}

// ResetStrike resets sos_strike_count = 0, is_sos_banned = false, and records audit in sos_strikes.
func (r *Repository) ResetStrike(userID string, callerID string) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		res := tx.Exec(`
			UPDATE user_profiles
			SET sos_strike_count = 0, is_sos_banned = FALSE, banned_until = NULL
			WHERE user_id = ?
		`, userID)
		if res.Error != nil {
			return res.Error
		}
		if res.RowsAffected == 0 {
			return gorm.ErrRecordNotFound
		}

		return tx.Exec(`
			INSERT INTO sos_strikes (id, user_id, incident_id, reason, marked_by, created_at)
			VALUES (gen_random_uuid(), ?, NULL, 'Strike di-reset oleh admin', ?, NOW())
		`, userID, callerID).Error
	})
}

// ─── Ranks (Master Data) ──────────────────────────────────────────────────────

func (r *Repository) GetRanks() ([]MRank, error) {
	var ranks []MRank
	err := r.db.Order("min_exp ASC").Find(&ranks).Error
	return ranks, err
}

func (r *Repository) FindRankByID(id int) (*MRank, error) {
	var rank MRank
	if err := r.db.First(&rank, id).Error; err != nil {
		return nil, err
	}
	return &rank, nil
}

func (r *Repository) FindRankByName(name string) (*MRank, error) {
	var rank MRank
	if err := r.db.Where("LOWER(rank_name) = LOWER(?)", name).First(&rank).Error; err != nil {
		return nil, err
	}
	return &rank, nil
}

func (r *Repository) FindRankByMinExp(minExp int) (*MRank, error) {
	var rank MRank
	if err := r.db.Where("min_exp = ?", minExp).First(&rank).Error; err != nil {
		return nil, err
	}
	return &rank, nil
}

func (r *Repository) FindRankByNameExcludingID(name string, excludeID int) (*MRank, error) {
	var rank MRank
	if err := r.db.Where("LOWER(rank_name) = LOWER(?) AND id != ?", name, excludeID).First(&rank).Error; err != nil {
		return nil, err
	}
	return &rank, nil
}

func (r *Repository) FindRankByMinExpExcludingID(minExp int, excludeID int) (*MRank, error) {
	var rank MRank
	if err := r.db.Where("min_exp = ? AND id != ?", minExp, excludeID).First(&rank).Error; err != nil {
		return nil, err
	}
	return &rank, nil
}

func (r *Repository) FindHighestRankBelowExp(minExp int) (*MRank, error) {
	var rank MRank
	if err := r.db.Where("min_exp < ?", minExp).Order("min_exp DESC").First(&rank).Error; err != nil {
		return nil, err
	}
	return &rank, nil
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

func (r *Repository) DeleteRankWithAutoDowngrade(targetRankID int, fallbackRankID int) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		// 1. Reassign volunteers holding targetRankID to fallbackRankID
		if err := tx.Exec("UPDATE volunteer_reputation SET rank_id = ? WHERE rank_id = ?", fallbackRankID, targetRankID).Error; err != nil {
			return fmt.Errorf("gagal mendowngrade relawan: %w", err)
		}
		// 2. Delete the target rank
		result := tx.Delete(&MRank{}, targetRankID)
		if result.Error != nil {
			return result.Error
		}
		if result.RowsAffected == 0 {
			return fmt.Errorf("rank tidak ditemukan")
		}
		return nil
	})
}

func (r *Repository) DeleteRank(id int) error {
	result := r.db.Delete(&MRank{}, id)
	if result.RowsAffected == 0 {
		return fmt.Errorf("rank tidak ditemukan")
	}
	return result.Error
}

// ─── Statistics ───────────────────────────────────────────────────────────────

func (r *Repository) GetStats(period string) (*StatsResponse, error) {
	stats := &StatsResponse{
		ByType:   make(map[string]int64),
		ByStatus: make(map[string]int64),
	}

	// Tentukan rentang waktu berdasarkan period
	var dateFormat, interval string
	switch period {
	case PeriodWeek:
		dateFormat = "YYYY-MM-DD" // daily dots for 7 days
		interval = "7 days"
	case PeriodYear:
		dateFormat = "YYYY-MM" // monthly dots for 12 months
		interval = "12 months"
	default: // month (default)
		dateFormat = "YYYY-MM-DD" // daily dots for 30 days
		interval = "30 days"
	}

	// Semua query di bawah di-filter oleh rentang waktu yang dipilih
	const dateFilter = "created_at >= NOW() - CAST(? AS INTERVAL)"

	// Total counts (filtered by period)
	r.db.Raw(`SELECT COUNT(*) FROM incidents WHERE `+dateFilter, interval).Scan(&stats.TotalSOS)
	r.db.Raw(`SELECT COUNT(*) FROM incidents WHERE status = 'resolved' AND `+dateFilter, interval).Scan(&stats.TotalResolved)
	r.db.Raw(`SELECT COUNT(*) FROM incidents WHERE status = 'false_alarm' AND `+dateFilter, interval).Scan(&stats.TotalFalseAlarm)

	// Active volunteers (global, tidak di-filter period)
	r.db.Raw(`SELECT COUNT(*) FROM user_profiles WHERE is_verified_volunteer = true`).Scan(&stats.ActiveVolunteers)

	if stats.TotalSOS > 0 {
		stats.FalseAlarmRate = float64(stats.TotalFalseAlarm) / float64(stats.TotalSOS) * 100
	}

	// Avg response time (filtered by period)
	r.db.Raw(`
		SELECT COALESCE(AVG(EXTRACT(EPOCH FROM (completed_at - created_at)) / 60), 0)
		FROM incidents
		WHERE status = 'resolved' AND completed_at IS NOT NULL
		  AND `+dateFilter, interval).Scan(&stats.AvgResponseMinutes)

	// By type (filtered by period)
	type kv struct {
		Key   string `gorm:"column:key"`
		Count int64  `gorm:"column:count"`
	}
	var byType []kv
	r.db.Raw(`
		SELECT incident_type AS key, COUNT(*) AS count
		FROM incidents
		WHERE `+dateFilter+`
		GROUP BY incident_type
	`, interval).Scan(&byType)
	for _, v := range byType {
		stats.ByType[v.Key] = v.Count
	}

	// By status (filtered by period)
	var byStatus []kv
	r.db.Raw(`
		SELECT status AS key, COUNT(*) AS count
		FROM incidents
		WHERE `+dateFilter+`
		GROUP BY status
	`, interval).Scan(&byStatus)
	for _, v := range byStatus {
		stats.ByStatus[v.Key] = v.Count
	}

	// Trend SOS
	var monthly []struct {
		Month string `gorm:"column:month"`
		Count int64  `gorm:"column:count"`
	}
	r.db.Raw(`
		SELECT TO_CHAR(created_at, ?) AS month, COUNT(*) AS count
		FROM incidents
		WHERE `+dateFilter+`
		GROUP BY month
		ORDER BY month ASC
	`, dateFormat, interval).Scan(&monthly)
	for _, m := range monthly {
		stats.Monthly = append(stats.Monthly, MonthlyCount{Month: m.Month, Count: m.Count})
	}

	return stats, nil
}

// ─── Badges (Peringkat Relawan) ────────────────────────────────────────────────

func (r *Repository) FindAllBadges() ([]MBadge, error) {
	var badges []MBadge
	err := r.db.Order("badge_name asc").Find(&badges).Error
	return badges, err
}

func (r *Repository) CreateBadge(badge *MBadge) error {
	return r.db.Create(badge).Error
}

func (r *Repository) UpdateBadge(id string, req *BadgeRequest) error {
	return r.db.Model(&MBadge{}).Where("id = ?", id).Updates(map[string]interface{}{
		"badge_name":  req.BadgeName,
		"description": req.Description,
		"icon_url":    req.IconURL,
	}).Error
}

func (r *Repository) DeleteBadge(id string) error {
	return r.db.Delete(&MBadge{}, "id = ?", id).Error
}
