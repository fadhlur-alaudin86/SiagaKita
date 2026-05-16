package incident

import (
	"errors"
	"time"

	"github.com/lib/pq"
	"gorm.io/gorm"
)

// Repository handles all DB operations for the incident domain.
type Repository struct {
	db *gorm.DB
}

// NewRepository creates a new incident Repository.
func NewRepository(db *gorm.DB) *Repository {
	return &Repository{db: db}
}

// ─── Incident (Jalur A - SOS Darurat) ─────────────────────────────────────────

func (r *Repository) CreateIncident(inc *Incident) error {
	return r.db.Create(inc).Error
}

func (r *Repository) FindByID(id string) (*Incident, error) {
	var inc Incident
	if err := r.db.First(&inc, "id = ?", id).Error; err != nil {
		return nil, err
	}
	return &inc, nil
}

func (r *Repository) UpdateStatus(id, status string) error {
	updates := map[string]interface{}{"status": status, "updated_at": time.Now()}
	if status == "resolved" || status == "handled" || status == "canceled" || status == "false_alarm" {
		updates["completed_at"] = time.Now()
	}
	return r.db.Model(&Incident{}).Where("id = ?", id).Updates(updates).Error
}

func (r *Repository) UpdateType(id, incidentType string) error {
	return r.db.Model(&Incident{}).Where("id = ?", id).
		Updates(map[string]interface{}{"incident_type": incidentType, "updated_at": time.Now()}).Error
}

func (r *Repository) MarkResolved(id string) (*Incident, error) {
	now := time.Now()
	if err := r.db.Model(&Incident{}).Where("id = ?", id).
		Updates(map[string]interface{}{"status": "resolved", "completed_at": now, "updated_at": now}).Error; err != nil {
		return nil, err
	}
	return r.FindByID(id)
}

// MarkCancelled memperbarui status insiden menjadi 'canceled' (dibatalkan user).
// Bisa dilakukan jika status masih 'grace_period', 'broadcasting', atau 'handled'.
func (r *Repository) MarkCancelled(id string) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		now := time.Now()
		// 1. Update incident
		db := tx.Model(&Incident{}).
			Where("id = ? AND status IN (?, ?, ?)", id, "grace_period", "broadcasting", "handled").
			Updates(map[string]interface{}{
				"status":        "canceled",
				"agency_status": "canceled", // Supaya instansi tahu ini dibatalkan
				"completed_at":  now,
				"updated_at":    now,
			})

		if db.Error != nil {
			return db.Error
		}
		if db.RowsAffected == 0 {
			return errors.New("conflict: incident cannot be canceled at its current status")
		}

		// 2. canceled all active incident responses (termasuk on_scene)
		if err := tx.Model(&IncidentResponse{}).
			Where("incident_id = ? AND status IN (?, ?, ?)", id, "en_route", "waiting_review", "on_scene").
			Updates(map[string]interface{}{
				"status": "canceled",
			}).Error; err != nil {
			return err
		}

		return nil
	})
}

// UploadEvidence menyimpan URL foto dan audio bukti situasi SOS pasca broadcasting.
func (r *Repository) UploadEvidence(id string, photoPaths []string, audioPath *string) error {
	updates := map[string]interface{}{"updated_at": time.Now()}
	if len(photoPaths) > 0 {
		updates["photo_paths"] = pq.StringArray(photoPaths)
	}
	if audioPath != nil {
		updates["audio_path"] = *audioPath
	}
	return r.db.Model(&Incident{}).Where("id = ?", id).Updates(updates).Error
}

func (r *Repository) MarkFalseAlarm(id string) error {
	return r.db.Model(&Incident{}).Where("id = ?", id).
		Updates(map[string]interface{}{"status": "false_alarm", "completed_at": time.Now(), "updated_at": time.Now()}).Error
}

func (r *Repository) UpdateLocation(id string, lat, lng float64) error {
	return r.db.Model(&Incident{}).Where("id = ?", id).
		Updates(map[string]interface{}{"latitude": lat, "longitude": lng, "updated_at": time.Now()}).Error
}

func (r *Repository) FindActiveByReporter(reporterID string) (*Incident, error) {
	var inc Incident
	err := r.db.Where(
		"reporter_id = ? AND status NOT IN ('resolved','false_alarm','canceled')", reporterID,
	).Order("created_at DESC").First(&inc).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &inc, err
}

// FindHistoryByReporter mengembalikan daftar insiden yang sudah selesai (resolved/false_alarm/canceled) untuk reporter tertentu.
func (r *Repository) FindHistoryByReporter(reporterID string) ([]Incident, error) {
	var incs []Incident
	err := r.db.Where(
		"reporter_id = ? AND status IN ('resolved','false_alarm','canceled')", reporterID,
	).Order("created_at DESC").Find(&incs).Error
	return incs, err
}

// FindAllActive mengembalikan semua incident aktif dengan data reporter lengkap (JOIN).
func (r *Repository) FindAllActive() ([]AllActiveIncidentResponse, error) {
	var results []AllActiveIncidentResponse
	err := r.db.Raw(`
		SELECT
			i.id,
			i.reporter_id,
			COALESCE(up.full_name, u.email, 'Tidak diketahui') AS reporter_name,
			up.phone_number AS reporter_phone,
			up.blood_type,
			up.allergies,
			i.incident_type,
			i.status,
			i.handled_by_agency_id,
			i.agency_status,
			i.latitude,
			i.longitude,
			i.address_detail,
			i.reporter_trust_label,
			i.created_at,
			i.updated_at,
			i.completed_at,
			CASE WHEN up.nik_verification_status = 'approved' THEN true ELSE false END AS is_nik_verified,
			up.is_phone_verified,
			CAST(up.date_of_birth AS VARCHAR) AS reporter_dob,
			up.domicile AS reporter_domicile,
			up.bio AS reporter_bio,
			(SELECT contact_name || ' (' || contact_phone || ')' FROM emergency_contacts ec WHERE ec.user_id = i.reporter_id AND ec.deleted_at IS NULL LIMIT 1) AS reporter_emergency_contact,
			array_to_json(COALESCE(i.photo_paths, ARRAY[]::text[]))::text AS photo_paths,
			i.audio_path,
			(SELECT status FROM incident_responses ir WHERE ir.incident_id = i.id ORDER BY accepted_at DESC LIMIT 1) AS volunteer_response_status
		FROM incidents i
		LEFT JOIN users u ON u.id = i.reporter_id
		LEFT JOIN user_profiles up ON up.user_id = i.reporter_id
		WHERE i.status NOT IN ('resolved', 'false_alarm', 'canceled')
		ORDER BY i.created_at DESC
	`).Scan(&results).Error
	for i := range results {
		results[i].PhotoPaths = StringSlice(parsePhotoPathsJSON(results[i].PhotoPathsRaw))
	}
	return results, err
}

// FindAgencyHistory mengembalikan riwayat SOS dengan status resolved, false_alarm, atau canceled.
func (r *Repository) FindAgencyHistory() ([]AllActiveIncidentResponse, error) {
	var results []AllActiveIncidentResponse
	err := r.db.Raw(`
		SELECT
			i.id,
			i.reporter_id,
			COALESCE(up.full_name, u.email, 'Tidak diketahui') AS reporter_name,
			up.phone_number AS reporter_phone,
			up.blood_type,
			up.allergies,
			i.incident_type,
			i.status,
			i.handled_by_agency_id,
			i.agency_status,
			i.latitude,
			i.longitude,
			i.address_detail,
			i.reporter_trust_label,
			i.created_at,
			i.updated_at,
			i.completed_at,
			CASE WHEN up.nik_verification_status = 'approved' THEN true ELSE false END AS is_nik_verified,
			up.is_phone_verified,
			CAST(up.date_of_birth AS VARCHAR) AS reporter_dob,
			up.domicile AS reporter_domicile,
			up.bio AS reporter_bio,
			(SELECT contact_name || ' (' || contact_phone || ')' FROM emergency_contacts ec WHERE ec.user_id = i.reporter_id AND ec.deleted_at IS NULL LIMIT 1) AS reporter_emergency_contact,
			array_to_json(COALESCE(i.photo_paths, ARRAY[]::text[]))::text AS photo_paths,
			i.audio_path,
			(SELECT status FROM incident_responses ir WHERE ir.incident_id = i.id ORDER BY accepted_at DESC LIMIT 1) AS volunteer_response_status
		FROM incidents i
		LEFT JOIN users u ON u.id = i.reporter_id
		LEFT JOIN user_profiles up ON up.user_id = i.reporter_id
		WHERE i.status IN ('resolved', 'false_alarm', 'canceled')
		ORDER BY i.updated_at DESC
	`).Scan(&results).Error
	for i := range results {
		results[i].PhotoPaths = StringSlice(parsePhotoPathsJSON(results[i].PhotoPathsRaw))
	}
	return results, err
}

// ─── Incident Report (Jalur B - Laporan Warga) ────────────────────────────────

func (r *Repository) CreateReport(rep *IncidentReport) error {
	return r.db.Create(rep).Error
}

func (r *Repository) FindReports(status string) ([]IncidentReportResponse, error) {
	var reps []IncidentReportResponse
	query := `
		SELECT
			ir.id, ir.reporter_id, ir.incident_type, ir.urgency_level,
			ir.latitude, ir.longitude, ir.address_detail, ir.description,
			array_to_json(COALESCE(ir.photo_paths, ARRAY[]::text[]))::text AS photo_paths,
			ir.audio_path, ir.status, ir.created_at, ir.updated_at, ir.completed_at,
			COALESCE(up.full_name, u.email, 'Anonim') AS reporter_name,
			up.phone_number AS reporter_phone
		FROM incident_reports ir
		LEFT JOIN users u ON u.id = ir.reporter_id
		LEFT JOIN user_profiles up ON up.user_id = ir.reporter_id
	`
	args := []interface{}{}
	if status != "" {
		query += " WHERE ir.status = ?"
		args = append(args, status)
	}
	query += " ORDER BY ir.created_at DESC"
	err := r.db.Raw(query, args...).Scan(&reps).Error
	r.hydrateReportPhotoPaths(reps)
	return reps, err
}

func (r *Repository) hydrateReportPhotoPaths(reps []IncidentReportResponse) {
	for i := range reps {
		reps[i].PhotoPaths = StringSlice(parsePhotoPathsJSON(reps[i].PhotoPathsRaw))
	}
}

func (r *Repository) UpdateReportStatus(id, status string, urgency *int) error {
	updates := map[string]interface{}{"status": status, "updated_at": time.Now()}
	if urgency != nil {
		updates["urgency_level"] = *urgency
	} else if status == "rejected" {
		updates["urgency_level"] = gorm.Expr("NULL")
	}
	if status == "resolved" || status == "rejected" || status == "canceled" {
		updates["completed_at"] = time.Now()
	}
	return r.db.Model(&IncidentReport{}).Where("id = ?", id).Updates(updates).Error
}

func (r *Repository) FindReportsByUser(userID string) ([]IncidentReportResponse, error) {
	var reps []IncidentReportResponse
	query := `
		SELECT
			ir.id, ir.reporter_id, ir.incident_type, ir.urgency_level,
			ir.latitude, ir.longitude, ir.address_detail, ir.description,
			array_to_json(COALESCE(ir.photo_paths, ARRAY[]::text[]))::text AS photo_paths,
			ir.audio_path, ir.status, ir.created_at, ir.updated_at, ir.completed_at,
			COALESCE(up.full_name, u.email, 'Anonim') AS reporter_name,
			up.phone_number AS reporter_phone
		FROM incident_reports ir
		LEFT JOIN users u ON u.id = ir.reporter_id
		LEFT JOIN user_profiles up ON up.user_id = ir.reporter_id
		WHERE ir.reporter_id = ?
		ORDER BY ir.created_at DESC
	`
	err := r.db.Raw(query, userID).Scan(&reps).Error
	r.hydrateReportPhotoPaths(reps)
	return reps, err
}

func (r *Repository) CancelReport(reportID, reporterID string) error {
	var rep IncidentReport
	if err := r.db.Where("id = ? AND reporter_id = ?", reportID, reporterID).First(&rep).Error; err != nil {
		return errors.New("laporan tidak ditemukan")
	}
	if rep.Status != "sent" && rep.Status != "pending" {
		return errors.New("hanya laporan dengan status 'sent' atau 'pending' yang dapat dibatalkan")
	}
	return r.db.Model(&IncidentReport{}).Where("id = ?", reportID).
		Updates(map[string]interface{}{"status": "canceled", "updated_at": time.Now(), "completed_at": time.Now()}).Error
}

// ─── Strike & Ban ─────────────────────────────────────────────────────────────

// AddStrike inserts a sos_strikes row, increments user strike count in user_profiles,
// and auto-bans if count reaches 3. Returns (newCount, banned, error).
func (r *Repository) AddStrike(userID, incidentID, reason, givenBy string) (int, bool, error) {
	var strikeCount int
	var banned bool

	err := r.db.Transaction(func(tx *gorm.DB) error {
		var incID *string
		if incidentID != "" {
			incID = &incidentID
		}
		var gby *string
		if givenBy != "" {
			gby = &givenBy
		}
		// 1. Insert strike record
		if err := tx.Create(&SOSStrike{
			UserID: userID, IncidentID: incID, Reason: reason, GivenBy: gby,
		}).Error; err != nil {
			return err
		}

		// 2. Increment di user_profiles (bukan users)
		if err := tx.Table("user_profiles").Where("user_id = ?", userID).
			Update("sos_strike_count", gorm.Expr("sos_strike_count + 1")).Error; err != nil {
			return err
		}

		// 3. Baca nilai terbaru
		if err := tx.Table("user_profiles").Select("sos_strike_count").
			Where("user_id = ?", userID).Scan(&strikeCount).Error; err != nil {
			return err
		}

		// 4. Auto-ban jika >= 3
		if strikeCount >= 3 {
			banned = true
			if err := tx.Table("user_profiles").Where("user_id = ?", userID).
				Updates(map[string]interface{}{"is_sos_banned": true}).Error; err != nil {
				return err
			}
		}
		return nil
	})

	return strikeCount, banned, err
}

func (r *Repository) GetTrustLabel(userID string) (string, error) {
	var profile struct {
		NikVerificationStatus string
		IsPhoneVerified       bool
	}
	err := r.db.Table("user_profiles").
		Select("nik_verification_status, is_phone_verified").
		Where("user_id = ?", userID).Scan(&profile).Error

	if err != nil {
		return "unverified", err
	}

	if profile.NikVerificationStatus == "approved" && profile.IsPhoneVerified {
		return "verified", nil
	}
	if profile.IsPhoneVerified {
		return "standard", nil
	}
	return "unverified", nil
}

func (r *Repository) IsSOSBanned(userID string) (bool, error) {
	var count int64
	err := r.db.Table("user_profiles").
		Where("user_id = ? AND is_sos_banned = true", userID).
		Count(&count).Error
	return count > 0, err
}

func (r *Repository) GetStrikeCount(userID string) (int, error) {
	var count int
	err := r.db.Table("user_profiles").Select("sos_strike_count").
		Where("user_id = ?", userID).Scan(&count).Error
	return count, err
}

// ─── Volunteer XP & Rank ──────────────────────────────────────────────────────

func (r *Repository) CreateResponse(resp *IncidentResponse) error {
	now := time.Now()
	resp.AcceptedAt = now
	return r.db.Create(resp).Error
}

func (r *Repository) GetReputation(userID string) (*VolunteerReputation, error) {
	var rep VolunteerReputation
	err := r.db.Where("user_id = ?", userID).First(&rep).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &rep, err
}

func (r *Repository) UpsertReputation(userID string, addXP, addRescues int) (*VolunteerReputation, error) {
	var rep VolunteerReputation
	err := r.db.Where("user_id = ?", userID).First(&rep).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		rep = VolunteerReputation{UserID: userID, ExpPoints: addXP, TotalRescues: addRescues, UpdatedAt: time.Now()}
		return &rep, r.db.Create(&rep).Error
	}
	if err != nil {
		return nil, err
	}
	rep.ExpPoints += addXP
	rep.TotalRescues += addRescues
	rep.UpdatedAt = time.Now()
	return &rep, r.db.Save(&rep).Error
}

func (r *Repository) GetRankForXP(totalXP int) (*MRank, error) {
	var rank MRank
	err := r.db.Where("min_exp <= ?", totalXP).Order("min_exp DESC").First(&rank).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &rank, err
}

func (r *Repository) UpdateRank(userID string, rankID uint) error {
	return r.db.Model(&VolunteerReputation{}).Where("user_id = ?", userID).
		Updates(map[string]interface{}{"rank_id": rankID, "updated_at": time.Now()}).Error
}

// ─── Nearby (untuk Relawan) ───────────────────────────────────────────────────

// FindNearby mengembalikan SOS aktif dalam radius `radiusKm` kilometer dari koordinat (lat, lng).
// Menggunakan formula haversine dengan PostgreSQL native functions.
// volunteerID digunakan untuk mengecualikan SOS milik relawan sendiri.
func (r *Repository) FindNearby(lat, lng, radiusKm float64, volunteerID string) ([]NearbyIncidentResponse, error) {
	var results []NearbyIncidentResponse
	err := r.db.Raw(`
		SELECT
			id,
			incident_type,
			status,
			latitude,
			longitude,
			address_detail,
			reporter_trust_label,
			created_at,
			(
				6371 * acos(
					LEAST(1.0, cos(radians($1)) * cos(radians(latitude)) *
					cos(radians(longitude) - radians($2)) +
					sin(radians($1)) * sin(radians(latitude)))
				)
			) AS distance_km,
			array_to_json(COALESCE(photo_paths, ARRAY[]::text[]))::text AS photo_paths,
			audio_path
		FROM incidents
		WHERE status NOT IN ('resolved', 'false_alarm', 'canceled')
		  AND reporter_id != $4
		  -- Relawan tidak melihat SOS yang sudah ia selesaikan (waiting_review/completed)
		  -- tapi masih bisa accept SOS lain selama instansi belum resolve
		  AND NOT EXISTS (
			SELECT 1 FROM incident_responses ir2
			WHERE ir2.incident_id = incidents.id
			  AND ir2.responder_id = $4
			  AND ir2.status IN ('waiting_review', 'completed', 'on_scene')
		  )
		  AND (
			6371 * acos(
				LEAST(1.0, cos(radians($1)) * cos(radians(latitude)) *
				cos(radians(longitude) - radians($2)) +
				sin(radians($1)) * sin(radians(latitude)))
			)
		  ) <= $3
		ORDER BY distance_km ASC
	`, lat, lng, radiusKm, volunteerID).Scan(&results).Error
	for i := range results {
		results[i].PhotoPaths = StringSlice(parsePhotoPathsJSON(results[i].PhotoPathsRaw))
	}
	return results, err
}

// AcceptIncident membuat record incident_response dan update status incident ke 'handled' jika masih broadcasting.
func (r *Repository) AcceptIncident(incidentID, volunteerID string) (*IncidentResponse, error) {
	var resp IncidentResponse
	err := r.db.Transaction(func(tx *gorm.DB) error {
		// Cek apakah incident ada dan belum selesai
		var inc Incident
		if err := tx.Where("id = ? AND status NOT IN ('resolved','false_alarm','canceled')", incidentID).
			First(&inc).Error; err != nil {
			return errors.New("incident tidak ditemukan atau sudah selesai")
		}

		// Cek apakah relawan sudah pernah menerima incident ini
		var existing int64
		tx.Model(&IncidentResponse{}).
			Where("incident_id = ? AND responder_id = ?", incidentID, volunteerID).
			Count(&existing)
		if existing > 0 {
			return errors.New("kamu sudah menerima incident ini")
		}

		// Buat record response
		now := time.Now()
		resp = IncidentResponse{
			IncidentID:  incidentID,
			ResponderID: volunteerID,
			Status:      "on_scene",
			AcceptedAt:  now,
		}
		if err := tx.Create(&resp).Error; err != nil {
			return err
		}

		// Update status incident ke 'handled' jika masih broadcasting
		if inc.Status == "broadcasting" {
			tx.Model(&Incident{}).Where("id = ?", incidentID).
				Updates(map[string]interface{}{"status": "handled", "updated_at": time.Now()})
		}

		return nil
	})
	return &resp, err
}

// ─── Lanjutan Handling & Gamifikasi ──────────────────────────────────────────

func (r *Repository) AgencyHandleSOS(incidentID, agencyID string) error {
	return r.db.Model(&Incident{}).Where("id = ? AND status NOT IN ('resolved','false_alarm','canceled')", incidentID).
		Updates(map[string]interface{}{
			"status":               "handled",
			"handled_by_agency_id": agencyID,
			"agency_status":        "handling",
			"updated_at":           time.Now(),
		}).Error
}

func (r *Repository) VolunteerCompleteSOS(incidentID, volunteerID, photoURL string) error {
	return r.db.Model(&IncidentResponse{}).
		Where("incident_id = ? AND responder_id = ?", incidentID, volunteerID).
		Updates(map[string]interface{}{
			"status":          "waiting_review",
			"proof_photo_url": photoURL,
			"completed_at":    time.Now(),
		}).Error
}

func (r *Repository) AgencyReviewVolunteer(incidentID, volunteerID string, approve bool) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		var resp IncidentResponse
		if err := tx.Where("incident_id = ? AND responder_id = ? AND status = 'waiting_review'", incidentID, volunteerID).First(&resp).Error; err != nil {
			return errors.New("response relawan tidak ditemukan atau bukan berstatus waiting_review")
		}

		if approve {
			// Terima pekerjaan relawan
			tx.Model(&IncidentResponse{}).Where("id = ?", resp.ID).Update("status", "completed")
			// Selesaikan incident global
			tx.Model(&Incident{}).Where("id = ?", incidentID).
				Updates(map[string]interface{}{"status": "resolved", "completed_at": time.Now(), "updated_at": time.Now()})
		} else {
			// Tolak pekerjaan relawan
			tx.Model(&IncidentResponse{}).Where("id = ?", resp.ID).Update("status", "rejected")
		}
		return nil
	})
}

func (r *Repository) FindResponsesByIncident(incidentID string) ([]IncidentResponse, error) {
	var responses []IncidentResponse
	err := r.db.Where("incident_id = ?", incidentID).Find(&responses).Error
	return responses, err
}

func (r *Repository) GetMissionHistory(volunteerID string) ([]MissionHistoryResponse, error) {
	var results []MissionHistoryResponse
	err := r.db.Raw(`
		SELECT 
			i.id,
			i.incident_type,
			i.status,
			ir.status as response_status,
			i.address_detail,
			CAST(ir.accepted_at AS VARCHAR) AS accepted_at
		FROM incident_responses ir
		JOIN incidents i ON i.id = ir.incident_id
		WHERE ir.responder_id = $1
		ORDER BY ir.accepted_at DESC
	`, volunteerID).Scan(&results).Error
	return results, err
}

// GetActiveResponse mengembalikan misi aktif relawan (status on_scene).
func (r *Repository) GetActiveResponse(volunteerID string) (*ActiveResponseDTO, error) {
	var result ActiveResponseDTO
	err := r.db.Raw(`
		SELECT
			ir.id       AS response_id,
			i.id        AS incident_id,
			i.incident_type,
			ir.status,
			i.latitude  AS reporter_latitude,
			i.longitude AS reporter_longitude,
			i.address_detail,
			CAST(ir.accepted_at AS VARCHAR) AS accepted_at
		FROM incident_responses ir
		JOIN incidents i ON i.id = ir.incident_id
		WHERE ir.responder_id = $1
		  AND ir.status IN ('on_scene', 'waiting_review')
		ORDER BY ir.accepted_at DESC
		LIMIT 1
	`, volunteerID).Scan(&result).Error
	if err != nil {
		return nil, err
	}
	if result.IncidentID == "" {
		return nil, nil // tidak ada misi aktif
	}
	return &result, nil
}

// UpdateResponseLocation memperbarui koordinat relawan pada incident_response aktif.
func (r *Repository) UpdateResponseLocation(incidentID, volunteerID string, lat, lng float64, address *string) error {
	updates := map[string]interface{}{
		"latitude":  lat,
		"longitude": lng,
	}
	if address != nil {
		updates["address_detail"] = *address
	}
	return r.db.Model(&IncidentResponse{}).
		Where("incident_id = ? AND responder_id = ? AND status = 'on_scene'", incidentID, volunteerID).
		Updates(updates).Error
}
