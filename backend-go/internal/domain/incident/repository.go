package incident

import (
	"errors"
	"time"

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

// ─── Incident (Jalur A — SOS Darurat) ─────────────────────────────────────────

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
	return r.db.Model(&Incident{}).Where("id = ?", id).
		Updates(map[string]interface{}{"status": status, "updated_at": time.Now()}).Error
}

func (r *Repository) UpdateType(id, incidentType string) error {
	return r.db.Model(&Incident{}).Where("id = ?", id).
		Updates(map[string]interface{}{"incident_type": incidentType, "updated_at": time.Now()}).Error
}

func (r *Repository) MarkResolved(id string) (*Incident, error) {
	now := time.Now()
	if err := r.db.Model(&Incident{}).Where("id = ?", id).
		Updates(map[string]interface{}{"status": "resolved", "resolved_at": now, "updated_at": now}).Error; err != nil {
		return nil, err
	}
	return r.FindByID(id)
}

func (r *Repository) MarkCancelled(id string) error {
	return r.db.Model(&Incident{}).Where("id = ?", id).
		Updates(map[string]interface{}{"status": "false_alarm", "updated_at": time.Now()}).Error
}

func (r *Repository) MarkFalseAlarm(id string) error {
	return r.db.Model(&Incident{}).Where("id = ?", id).
		Updates(map[string]interface{}{"status": "false_alarm", "updated_at": time.Now()}).Error
}

func (r *Repository) UpdateLocation(id string, lat, lng float64) error {
	return r.db.Model(&Incident{}).Where("id = ?", id).
		Updates(map[string]interface{}{"latitude": lat, "longitude": lng, "updated_at": time.Now()}).Error
}

func (r *Repository) FindActiveByReporter(reporterID string) (*Incident, error) {
	var inc Incident
	err := r.db.Where(
		"reporter_id = ? AND status NOT IN ('resolved','false_alarm')", reporterID,
	).Order("created_at DESC").First(&inc).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &inc, err
}

// ─── Incident Report (Jalur B — Laporan Warga) ────────────────────────────────

func (r *Repository) CreateReport(rep *IncidentReport) error {
	return r.db.Create(rep).Error
}

func (r *Repository) FindReports(status string) ([]IncidentReport, error) {
	var reps []IncidentReport
	q := r.db.Order("created_at DESC")
	if status != "" {
		q = q.Where("status = ?", status)
	}
	return reps, q.Find(&reps).Error
}

func (r *Repository) UpdateReportStatus(id, status string) error {
	return r.db.Model(&IncidentReport{}).Where("id = ?", id).
		Updates(map[string]interface{}{"status": status, "updated_at": time.Now()}).Error
}

func (r *Repository) FindReportsByUser(userID string) ([]IncidentReport, error) {
	var reps []IncidentReport
	return reps, r.db.Where("reporter_id = ?", userID).Order("created_at DESC").Find(&reps).Error
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
	resp.AcceptedAt = &now
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
