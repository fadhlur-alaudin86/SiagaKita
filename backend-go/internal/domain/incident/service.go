package incident

import (
	"context"
	"errors"
	"fmt"
	"math"
	"sync"
	"time"

	"siagakita-backend/internal/utils"

	"github.com/lib/pq"
	"github.com/redis/go-redis/v9"
)

var incidentTypeMultiplier = map[string]float64{
	"medical":           1.5,
	"fire":              1.3,
	"rescue":            1.4,
	"crime":             1.2,
	"accident":          1.3,
	"disaster":          1.4,
	"general":           1.0,
	IncidentTypeUnknown: 1.0,
}

var validIncidentTypes = map[string]bool{
	"medical":  true,
	"fire":     true,
	"crime":    true,
	"rescue":   true,
	"accident": true,
	"disaster": true,
	"general":  true,
}

type Service struct {
	repo        *Repository
	rdb         *redis.Client
	graceTimers sync.Map // incidentID -> context.CancelFunc
	// OnBroadcast dipanggil saat auto-promote grace_period → broadcasting
	// agar WS event INCOMING_EMERGENCY dikirim ke console.
	OnBroadcast func(incidentID string)
	// OnBadgeUnlocked dipanggil saat relawan mendapatkan badge tier baru.
	OnBadgeUnlocked func(userID string, badges []BadgeUnlocked)
}

func NewService(repo *Repository, rdb *redis.Client) *Service {
	return &Service{repo: repo, rdb: rdb}
}

// ─── TriggerSOS (Jalur A) ─────────────────────────────────────────────────────

func (s *Service) TriggerSOS(reporterID string, req *TriggerSOSRequest) (*TriggerSOSResponse, error) {
	banned, err := s.repo.IsSOSBanned(reporterID)
	if err != nil {
		return nil, err
	}
	if banned {
		return nil, ErrSOSBanned
	}

	// Guard: cegah duplikat SOS — jika user sudah punya incident aktif, kembalikan yang ada
	existing, _ := s.repo.FindActiveByReporter(reporterID)
	if existing != nil {
		return &TriggerSOSResponse{
			IncidentID: existing.ID,
			Status:     existing.Status,
			Message:    "SOS sudah aktif.",
		}, nil
	}

	trustLabel, _ := s.repo.GetTrustLabel(reporterID)

	inc := &Incident{
		ReporterID:         reporterID,
		Latitude:           req.Latitude,
		Longitude:          req.Longitude,
		IncidentType:       IncidentTypeUnknown,
		UrgencyLevel:       "critical",
		AddressDetail:      &req.AddressDetail,
		ReporterTrustLabel: trustLabel,
		Status:             StatusGracePeriod,
		CreatedAt:          time.Now(),
		UpdatedAt:          time.Now(),
	}

	if err := s.repo.CreateIncident(inc); err != nil {
		return nil, err
	}

	// Auto-promote: jadwalkan promosi grace_period → broadcasting setelah 15 detik
	ctx, cancel := context.WithCancel(context.Background())
	s.graceTimers.Store(inc.ID, cancel)
	go s.autoPromoteGracePeriod(ctx, inc.ID)

	return &TriggerSOSResponse{
		IncidentID: inc.ID,
		Status:     inc.Status,
		Message:    "SOS diterima. Pilih jenis darurat atau tunggu 10 detik untuk dikirim otomatis.",
	}, nil
}

// ─── UpdateType (Grace Period) ────────────────────────────────────────────────

func (s *Service) UpdateType(incidentID, reporterID, incidentType string) error {
	if cancel, ok := s.graceTimers.LoadAndDelete(incidentID); ok {
		cancel.(context.CancelFunc)()
	}

	if !validIncidentTypes[incidentType] {
		return fmt.Errorf("tipe insiden tidak valid: %s", incidentType)
	}
	inc, err := s.repo.FindByID(incidentID)
	if err != nil {
		return err
	}
	if inc.ReporterID != reporterID {
		return ErrUnauthorized
	}
	if inc.Status != "grace_period" {
		return errors.New("tipe hanya bisa diubah saat grace period")
	}
	if err := s.repo.UpdateType(incidentID, incidentType); err != nil {
		return err
	}
	return s.repo.UpdateStatus(incidentID, "broadcasting")
}

// PromoteToBroadcasting mengubah status grace_period → broadcasting tanpa mengubah tipe.
func (s *Service) PromoteToBroadcasting(incidentID, reporterID string) error {
	if cancel, ok := s.graceTimers.LoadAndDelete(incidentID); ok {
		cancel.(context.CancelFunc)()
	}

	inc, err := s.repo.FindByID(incidentID)
	if err != nil {
		return err
	}
	if inc.ReporterID != reporterID {
		return ErrUnauthorized
	}
	return s.repo.UpdateStatus(incidentID, "broadcasting")
}

// autoPromoteGracePeriod secara otomatis mempromosikan incident dari grace_period ke broadcasting
// setelah 15 detik atau dibatalkan lebih awal melalui ctx.
func (s *Service) autoPromoteGracePeriod(ctx context.Context, incidentID string) {
	defer s.graceTimers.Delete(incidentID)

	select {
	case <-time.After(15 * time.Second):
	case <-ctx.Done():
		return
	}

	inc, err := s.repo.FindByID(incidentID)
	if err != nil {
		utils.Error().Err(err).Str("incident_id", incidentID).Msg("[IncidentService] Failed to query incident for auto-promotion")
		return
	}
	if inc == nil {
		return
	}
	// Hanya promosikan jika masih grace_period (belum diubah oleh mobile)
	if inc.Status == "grace_period" {
		if err := s.repo.UpdateStatus(incidentID, "broadcasting"); err != nil {
			utils.Error().Err(err).Str("incident_id", incidentID).Msg("[IncidentService] Failed to auto-promote incident status to broadcasting")
			return
		}
		// Trigger WS broadcast ke console agar alarm berbunyi
		if s.OnBroadcast != nil {
			s.OnBroadcast(incidentID)
		}
	}
}

// ─── CancelSOS ────────────────────────────────────────────────────────────────

func (s *Service) CancelSOS(incidentID, reporterID string) error {
	if cancel, ok := s.graceTimers.LoadAndDelete(incidentID); ok {
		cancel.(context.CancelFunc)()
	}

	inc, err := s.repo.FindByID(incidentID)
	if err != nil {
		return err
	}
	if inc.ReporterID != reporterID {
		return ErrUnauthorized
	}
	return s.repo.MarkCancelled(incidentID)
}

// ─── UploadEvidence ──────────────────────────────────────────────────────────
// Menerima foto kamera depan dan audio 5 detik sebagai bukti situasi SOS.
// Dipanggil secara background SETELAH insiden masuk fase broadcasting.

func (s *Service) UploadEvidence(incidentID, reporterID string, photoPaths []string, audioPath *string) error {
	inc, err := s.repo.FindByID(incidentID)
	if err != nil {
		return err
	}
	if inc.ReporterID != reporterID {
		return ErrUnauthorized
	}
	return s.repo.UploadEvidence(incidentID, photoPaths, audioPath)
}

// ─── MarkFalseAlarm (oleh Admin) ─────────────────────────────────────────────

func (s *Service) MarkFalseAlarm(incidentID, adminID, reason string) (*FalseAlarmResponse, error) {
	inc, err := s.repo.FindByID(incidentID)
	if err != nil {
		return nil, err
	}

	if err := s.repo.MarkFalseAlarm(incidentID); err != nil {
		return nil, err
	}

	strikeCount, banned, err := s.repo.AddStrike(inc.ReporterID, incidentID, reason, adminID)
	if err != nil {
		return nil, err
	}

	msg := fmt.Sprintf("Insiden ditandai false alarm. Pelanggaran %d/3.", strikeCount)
	if banned {
		msg = "Insiden ditandai false alarm. Akun pelapor telah diblokir dari fitur SOS (3 pelanggaran)."
	}

	return &FalseAlarmResponse{
		MarkedFalseAlarm: true,
		StrikeCount:      strikeCount,
		UserBanned:       banned,
		Message:          msg,
	}, nil
}

// ─── UpdateLocation ───────────────────────────────────────────────────────────

func (s *Service) UpdateLocation(incidentID string, lat, lng float64) error {
	return s.repo.UpdateLocation(incidentID, lat, lng)
}

// ─── GetActive ────────────────────────────────────────────────────────────────

func (s *Service) GetActive(reporterID string) (*ActiveIncidentResponse, error) {
	inc, err := s.repo.FindActiveByReporter(reporterID)
	if err != nil {
		return nil, err
	}
	if inc == nil {
		return nil, nil
	}

	// Ambil status relawan aktif (en_route atau waiting_review)
	var volunteerStatus *string
	s.repo.db.Raw(`
		SELECT status FROM incident_responses
		WHERE incident_id = ? AND status IN ('en_route', 'waiting_review', 'on_scene')
		ORDER BY created_at ASC LIMIT 1
	`, inc.ID).Scan(&volunteerStatus)

	var volunteerLocations []VolunteerLocation
	s.repo.db.Raw(`
		SELECT u.full_name as name, ir.latitude, ir.longitude 
		FROM incident_responses ir
		JOIN users u ON u.id = ir.responder_id
		WHERE ir.incident_id = ? AND ir.status IN ('en_route', 'waiting_review', 'on_scene')
	`, inc.ID).Scan(&volunteerLocations)

	var volunteerNames []string
	for _, vl := range volunteerLocations {
		volunteerNames = append(volunteerNames, vl.Name)
	}

	agencyStatus := inc.AgencyStatus
	var agencyStatusPtr *string
	if agencyStatus != "" && agencyStatus != "pending" {
		agencyStatusPtr = &agencyStatus
	}

	var agencyNamePtr *string
	if inc.HandledByAgencyID != nil {
		var agencyName string
		s.repo.db.Raw(`SELECT name FROM agencies WHERE id = ?`, inc.HandledByAgencyID).Scan(&agencyName)
		if agencyName != "" {
			agencyNamePtr = &agencyName
		}
	}

	return &ActiveIncidentResponse{
		IncidentID:              inc.ID,
		Status:                  inc.Status,
		IncidentType:            inc.IncidentType,
		Latitude:                inc.Latitude,
		Longitude:               inc.Longitude,
		ReporterTrustLabel:      inc.ReporterTrustLabel,
		CreatedAt:               inc.CreatedAt.Format(time.RFC3339),
		AgencyStatus:            agencyStatusPtr,
		HandledByAgencyID:       inc.HandledByAgencyID,
		AgencyName:              agencyNamePtr,
		VolunteerResponseStatus: volunteerStatus,
		VolunteerNames:          volunteerNames,
		VolunteerLocations:      volunteerLocations,
	}, nil
}

// ─── GetHistory ───────────────────────────────────────────────────────────────

func (s *Service) GetHistory(reporterID string) ([]ActiveIncidentResponse, error) {
	incs, err := s.repo.FindHistoryByReporter(reporterID)
	if err != nil {
		return nil, err
	}

	var history []ActiveIncidentResponse
	for _, inc := range incs {
		history = append(history, ActiveIncidentResponse{
			IncidentID:         inc.ID,
			Status:             inc.Status,
			IncidentType:       inc.IncidentType,
			Latitude:           inc.Latitude,
			Longitude:          inc.Longitude,
			ReporterTrustLabel: inc.ReporterTrustLabel,
			CreatedAt:          inc.CreatedAt.Format(time.RFC3339),
		})
	}
	// Return empty array instead of null for empty history
	if history == nil {
		history = []ActiveIncidentResponse{}
	}
	return history, nil
}

// GetAllActive mengembalikan semua incident aktif (untuk console desktop).
func (s *Service) GetAllActive() ([]AllActiveIncidentResponse, error) {
	return s.repo.FindAllActive()
}

func (s *Service) GetAgencyHistory() ([]AllActiveIncidentResponse, error) {
	return s.repo.FindAgencyHistory()
}

// ─── Laporan Warga (Jalur B) ──────────────────────────────────────────────────

func (s *Service) CreateReport(reporterID string, req *CreateReportRequest, photoPaths []string, audioPath *string) (*IncidentReport, error) {
	if req.IncidentType == "" || req.IncidentType == "unknown" {
		return nil, errors.New("tipe insiden wajib diisi dan tidak boleh 'unknown' untuk laporan warga")
	}
	if !validIncidentTypes[req.IncidentType] {
		return nil, fmt.Errorf("tipe insiden tidak valid: %s", req.IncidentType)
	}
	if req.Latitude == 0 && req.Longitude == 0 {
		return nil, errors.New("lokasi harus diisi (latitude dan longitude tidak boleh 0)")
	}

	rep := &IncidentReport{
		ReporterID:    reporterID,
		IncidentType:  req.IncidentType,
		Latitude:      req.Latitude,
		Longitude:     req.Longitude,
		AddressDetail: &req.AddressDetail,
		Status:        "sent",
		CreatedAt:     time.Now(),
		UpdatedAt:     time.Now(),
	}
	if req.Description != "" {
		rep.Description = &req.Description
	}
	if len(photoPaths) > 0 {
		rep.PhotoPaths = pq.StringArray(photoPaths)
	}
	rep.AudioPath = audioPath

	if err := s.repo.CreateReport(rep); err != nil {
		return nil, err
	}
	return rep, nil
}

func (s *Service) GetReports(status string) ([]IncidentReportResponse, error) {
	return s.repo.FindReports(status)
}

func (s *Service) GetReportsByUser(userID string) ([]IncidentReportResponse, error) {
	return s.repo.FindReportsByUser(userID)
}

func (s *Service) UpdateReportStatus(id, status string, urgency *int) error {
	return s.repo.UpdateReportStatus(id, status, urgency)
}

func (s *Service) CancelReport(reportID, reporterID string) error {
	// Memastikan hanya reporter yang membuat laporan tersebut dan status belum diproses.
	return s.repo.CancelReport(reportID, reporterID)
}

// ─── Resolve (oleh Relawan/Instansi) ──────────────────────────────────────────

func (s *Service) Resolve(incidentID, responderID string) (*ResolveResponse, error) {
	inc, err := s.repo.MarkResolved(incidentID)
	if err != nil {
		return nil, err
	}

	durationMinutes := inc.CompletedAt.Sub(inc.CreatedAt).Minutes()
	baseXP := 100
	speedBonus := math.Max(0, 50-durationMinutes)
	multiplier := incidentTypeMultiplier[inc.IncidentType]
	if multiplier == 0 {
		multiplier = 1.0
	}
	totalXP := int((float64(baseXP) + speedBonus) * multiplier)

	rep, err := s.repo.UpsertReputation(responderID, totalXP, 1)
	if err != nil {
		return nil, err
	}

	rankUp := false
	newRankName := ""
	newRank, err := s.repo.GetRankForXP(rep.ExpPoints)
	if err != nil {
		return nil, err
	}
	if newRank != nil {
		oldRankID := uint(0)
		if rep.RankID != nil {
			oldRankID = *rep.RankID
		}
		if newRank.ID != oldRankID {
			rankUp = true
			newRankName = newRank.RankName
			if err := s.repo.UpdateRank(responderID, newRank.ID); err != nil {
				utils.Error().Err(err).Str("user_id", responderID).Msg("[IncidentService] Failed to update user rank")
			}
		}
	}

	newBadges, err := s.EvaluateAndAwardMultiLevelBadges(responderID)
	if err != nil {
		utils.Error().Err(err).Str("responder_id", responderID).Msg("[IncidentService] Failed to evaluate badges")
	}

	return &ResolveResponse{
		Resolved:     true,
		XPEarned:     totalXP,
		NewTotalXP:   rep.ExpPoints,
		TotalRescues: rep.TotalRescues,
		RankUp:       rankUp,
		NewRank:      newRankName,
		NewBadges:    newBadges,
	}, nil
}

// ─── GetNearby (untuk Relawan) ────────────────────────────────────────────────

// GetNearby mengembalikan SOS aktif dalam radius `radiusKm` km dari posisi relawan.
// volunteerID digunakan untuk mengecualikan SOS milik relawan sendiri.
func (s *Service) GetNearby(lat, lng, radiusKm float64, volunteerID string) ([]NearbyIncidentResponse, error) {
	results, err := s.repo.FindNearby(lat, lng, radiusKm, volunteerID)
	if err != nil {
		return nil, err
	}
	if results == nil {
		results = []NearbyIncidentResponse{}
	}
	return results, nil
}

// AcceptIncident - relawan menerima SOS, buat record response + update status incident.
func (s *Service) AcceptIncident(incidentID, volunteerID string) (*AcceptSOSResponse, error) {
	resp, err := s.repo.AcceptIncident(incidentID, volunteerID)
	if err != nil {
		return nil, err
	}
	return &AcceptSOSResponse{
		Accepted:   true,
		IncidentID: incidentID,
		Status:     resp.Status,
		Message:    "Misi diterima. Segera menuju lokasi.",
	}, nil
}

// ─── Lanjutan Gamifikasi & Review ───────────────────────────────────────────

func (s *Service) AgencyHandleSOS(incidentID, agencyID string) error {
	return s.repo.AgencyHandleSOS(incidentID, agencyID)
}

func (s *Service) PersonnelUpdateStatus(incidentID, personnelID, newStatus, photoURL string) error {
	return s.repo.PersonnelUpdateStatus(incidentID, personnelID, newStatus, photoURL)
}

func (s *Service) VolunteerCompleteSOS(incidentID, volunteerID string, photoPaths []string) error {
	if len(photoPaths) == 0 {
		return errors.New("foto bukti wajib disertakan")
	}
	// Asumsi photoPaths[0] adalah bukti penyelesaian dari relawan
	return s.repo.VolunteerCompleteSOS(incidentID, volunteerID, photoPaths[0])
}

func (s *Service) AgencyReviewVolunteer(incidentID, volunteerID string, approve bool) (*ResolveResponse, error) {
	err := s.repo.AgencyReviewVolunteer(incidentID, volunteerID, approve)
	if err != nil {
		return nil, err
	}

	if approve {
		// Calculate XP
		inc, _ := s.repo.FindByID(incidentID)
		if inc != nil {
			durationMinutes := 10.0 // Default 10 minutes jika error
			if inc.CompletedAt != nil {
				durationMinutes = inc.CompletedAt.Sub(inc.CreatedAt).Minutes()
			}
			baseXP := 100
			speedBonus := math.Max(0, 50-durationMinutes)
			multiplier := incidentTypeMultiplier[inc.IncidentType]
			if multiplier == 0 {
				multiplier = 1.0
			}
			totalXP := int((float64(baseXP) + speedBonus) * multiplier)

			// Award XP
			rep, _ := s.repo.UpsertReputation(volunteerID, totalXP, 1)

			rankUp := false
			newRankName := ""
			if rep != nil {
				newRank, _ := s.repo.GetRankForXP(rep.ExpPoints)
				if newRank != nil {
					oldRankID := uint(0)
					if rep.RankID != nil {
						oldRankID = *rep.RankID
					}
					if newRank.ID != oldRankID {
						rankUp = true
						newRankName = newRank.RankName
						if err := s.repo.UpdateRank(volunteerID, newRank.ID); err != nil {
							utils.Error().Err(err).Str("user_id", volunteerID).Msg("[IncidentService] Failed to update volunteer rank")
						}
					}
				}

				newBadges, err := s.EvaluateAndAwardMultiLevelBadges(volunteerID)
				if err != nil {
					utils.Error().Err(err).Str("volunteer_id", volunteerID).Msg("[IncidentService] Failed to evaluate badges")
				}

				return &ResolveResponse{
					Resolved:     true,
					XPEarned:     totalXP,
					NewTotalXP:   rep.ExpPoints,
					TotalRescues: rep.TotalRescues,
					RankUp:       rankUp,
					NewRank:      newRankName,
					NewBadges:    newBadges,
				}, nil
			}
		}

		return &ResolveResponse{Resolved: true}, nil
	}

	// Jika ditolak, kembalikan response kosong
	return &ResolveResponse{Resolved: false}, nil
}

func (s *Service) AgencyResolveSOS(incidentID string) (*ResolveResponse, error) {
	inc, err := s.repo.MarkResolved(incidentID)
	if err != nil {
		return nil, err
	}

	// ─── Fallback Logic ──────────────────────────────────────────────────────────
	// Cari relawan yang berstatus en_route atau on_scene
	responses, err := s.repo.FindResponsesByIncident(incidentID)
	if err == nil {
		ctx, canceled := context.WithTimeout(context.Background(), 5*time.Second)
		defer canceled()
		for _, resp := range responses {
			if resp.Status == "en_route" || resp.Status == "on_scene" {
				// Cek posisi terakhir di Redis
				positions, err := s.rdb.GeoPos(ctx, "relawan:locations", resp.ResponderID).Result()
				if err == nil && len(positions) > 0 && positions[0] != nil {
					// Hitung jarak (Haversine)
					volunteerLat := positions[0].Latitude
					volunteerLng := positions[0].Longitude

					// Gunakan formula haversine sederhana (radius bumi = 6371 km)
					dLat := (inc.Latitude - volunteerLat) * math.Pi / 180.0
					dLon := (inc.Longitude - volunteerLng) * math.Pi / 180.0
					lat1 := volunteerLat * math.Pi / 180.0
					lat2 := inc.Latitude * math.Pi / 180.0

					a := math.Sin(dLat/2)*math.Sin(dLat/2) +
						math.Sin(dLon/2)*math.Sin(dLon/2)*math.Cos(lat1)*math.Cos(lat2)
					c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
					distanceKm := 6371 * c

					// Jika jarak <= 1 KM, berikan 50% XP
					if distanceKm <= 1.0 {
						baseXP := 100
						multiplier := incidentTypeMultiplier[inc.IncidentType]
						if multiplier == 0 {
							multiplier = 1.0
						}
						// 50% dari baseXP + multiplier, tanpa speed bonus
						totalXP := int((float64(baseXP) * multiplier) * 0.5)

						// Award XP
						if _, err := s.repo.UpsertReputation(resp.ResponderID, totalXP, 1); err != nil {
							utils.Error().Err(err).Str("user_id", resp.ResponderID).Msg("[IncidentService] Failed to award fallback reputation")
						}
					}
				}
				// Ubah status relawan menjadi canceled (oleh sistem/instansi)
				if err := s.repo.AgencyReviewVolunteer(incidentID, resp.ResponderID, false); err != nil {
					utils.Error().Err(err).Str("incident_id", incidentID).Str("volunteer_id", resp.ResponderID).Msg("[IncidentService] Failed to update volunteer review status")
				}
			}
		}
	}

	return &ResolveResponse{Resolved: true}, nil
}

func (s *Service) GetMissionHistory(volunteerID string) ([]MissionHistoryResponse, error) {
	history, err := s.repo.GetMissionHistory(volunteerID)
	if err != nil {
		return nil, err
	}
	if history == nil {
		history = []MissionHistoryResponse{}
	}
	return history, nil
}

// GetActiveResponse mengembalikan misi aktif relawan (status on_scene).
func (s *Service) GetActiveResponse(volunteerID string) (*ActiveResponseDTO, error) {
	return s.repo.GetActiveResponse(volunteerID)
}

// UpdateResponseLocation memperbarui lokasi relawan pada misi aktif.
func (s *Service) UpdateResponseLocation(incidentID, volunteerID string, lat, lng float64, address *string) error {
	return s.repo.UpdateResponseLocation(incidentID, volunteerID, lat, lng, address)
}

func (s *Service) GetMissionHistoryPaginated(volunteerID string, page, limit int) ([]MissionHistoryResponse, error) {
	offset := 0
	if page > 1 && limit > 0 {
		offset = (page - 1) * limit
	}
	history, err := s.repo.FindVolunteerMissionHistory(volunteerID, limit, offset)
	if err != nil {
		return nil, err
	}
	if history == nil {
		history = []MissionHistoryResponse{}
	}
	return history, nil
}

func (s *Service) GetVolunteerBadges(volunteerID string) ([]BadgeCategoryProgress, error) {
	badges, err := s.repo.FindVolunteerBadgesGrouped(volunteerID)
	if err != nil {
		return nil, err
	}
	if badges == nil {
		badges = []BadgeCategoryProgress{}
	}
	return badges, nil
}

func (s *Service) EvaluateAndAwardMultiLevelBadges(volunteerID string) ([]BadgeUnlocked, error) {
	masterBadges, err := s.repo.FindAllMasterBadges()
	if err != nil {
		return nil, err
	}
	if len(masterBadges) == 0 {
		return nil, nil
	}

	acquiredMap, err := s.repo.FindAcquiredBadgeIDs(volunteerID)
	if err != nil {
		return nil, err
	}

	stats, err := s.repo.GetVolunteerRescueStats(volunteerID)
	if err != nil {
		return nil, err
	}

	var newlyUnlocked []BadgeUnlocked
	for _, mb := range masterBadges {
		// If already earned, skip
		if _, exists := acquiredMap[mb.ID]; exists {
			continue
		}

		progress := stats.TotalRescues
		switch mb.BadgeCode {
		case "medic_specialist":
			progress = stats.MedicalRescues
		case "night_owl":
			progress = stats.NightRescues
		case "rapid_hero":
			progress = stats.RapidRescues
		}

		if progress >= mb.Threshold {
			awarded, err := s.repo.AwardBadgeTier(volunteerID, mb.ID)
			if err != nil {
				utils.Error().Err(err).
					Str("volunteer_id", volunteerID).
					Str("badge_code", mb.BadgeCode).
					Int("level", mb.Level).
					Msg("[IncidentService] Failed to award badge tier")
				continue
			}
			if awarded {
				unlocked := BadgeUnlocked{
					BadgeCode:   mb.BadgeCode,
					BadgeName:   mb.BadgeName,
					Level:       mb.Level,
					Threshold:   mb.Threshold,
					Description: mb.Description,
					IconURL:     mb.IconURL,
				}
				newlyUnlocked = append(newlyUnlocked, unlocked)
			}
		}
	}

	if len(newlyUnlocked) > 0 && s.OnBadgeUnlocked != nil {
		s.OnBadgeUnlocked(volunteerID, newlyUnlocked)
	}

	return newlyUnlocked, nil
}
