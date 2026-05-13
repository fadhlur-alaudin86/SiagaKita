package incident

import (
	"context"
	"errors"
	"fmt"
	"math"
	"time"

	"github.com/lib/pq"
	"github.com/redis/go-redis/v9"
)

var incidentTypeMultiplier = map[string]float64{
	"medical":  1.5,
	"fire":     1.3,
	"rescue":   1.4,
	"crime":    1.2,
	"accident": 1.3,
	"disaster": 1.4,
	"general":  1.0,
	"unknown":  1.0,
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
	repo *Repository
	rdb  *redis.Client
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
		return nil, errors.New("sos_banned: akun Anda dinonaktifkan dari fitur SOS karena pelanggaran berulang")
	}

	trustLabel, _ := s.repo.GetTrustLabel(reporterID)

	inc := &Incident{
		ReporterID:         reporterID,
		Latitude:           req.Latitude,
		Longitude:          req.Longitude,
		IncidentType:       "unknown",
		UrgencyLevel:       "critical",
		AddressDetail:      &req.AddressDetail,
		ReporterTrustLabel: trustLabel,
		Status:             "grace_period",
		CreatedAt:          time.Now(),
		UpdatedAt:          time.Now(),
	}

	if err := s.repo.CreateIncident(inc); err != nil {
		return nil, err
	}

	return &TriggerSOSResponse{
		IncidentID: inc.ID,
		Status:     inc.Status,
		Message:    "SOS diterima. Pilih jenis darurat atau tunggu 10 detik untuk dikirim otomatis.",
	}, nil
}

// ─── UpdateType (Grace Period) ────────────────────────────────────────────────

func (s *Service) UpdateType(incidentID, reporterID, incidentType string) error {
	if !validIncidentTypes[incidentType] {
		return fmt.Errorf("tipe insiden tidak valid: %s", incidentType)
	}
	inc, err := s.repo.FindByID(incidentID)
	if err != nil {
		return err
	}
	if inc.ReporterID != reporterID {
		return errors.New("unauthorized")
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
	inc, err := s.repo.FindByID(incidentID)
	if err != nil {
		return err
	}
	if inc.ReporterID != reporterID {
		return errors.New("unauthorized")
	}
	return s.repo.UpdateStatus(incidentID, "broadcasting")
}

// ─── CancelSOS ────────────────────────────────────────────────────────────────

func (s *Service) CancelSOS(incidentID, reporterID string) error {
	inc, err := s.repo.FindByID(incidentID)
	if err != nil {
		return err
	}
	if inc.ReporterID != reporterID {
		return errors.New("unauthorized")
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
		return errors.New("unauthorized")
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

	var agencyName *string
	if inc.HandledByAgencyID != nil {
		s.repo.db.Raw(`SELECT name FROM agencies WHERE id = ?`, inc.HandledByAgencyID).Scan(&agencyName)
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
		AgencyName:              agencyName,
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

	rep := &IncidentReport{
		ReporterID:   reporterID,
		IncidentType: req.IncidentType,
		Latitude:     req.Latitude,
		Longitude:    req.Longitude,
		Status:       "sent",
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
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

func (s *Service) GetReports(status string) ([]IncidentReport, error) {
	return s.repo.FindReports(status)
}

func (s *Service) GetReportsByUser(userID string) ([]IncidentReport, error) {
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
			_ = s.repo.UpdateRank(responderID, newRank.ID)
		}
	}

	return &ResolveResponse{
		Resolved:     true,
		XPEarned:     totalXP,
		NewTotalXP:   rep.ExpPoints,
		TotalRescues: rep.TotalRescues,
		RankUp:       rankUp,
		NewRank:      newRankName,
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
						_ = s.repo.UpdateRank(volunteerID, newRank.ID)
					}
				}
				
				return &ResolveResponse{
					Resolved:     true,
					XPEarned:     totalXP,
					NewTotalXP:   rep.ExpPoints,
					TotalRescues: rep.TotalRescues,
					RankUp:       rankUp,
					NewRank:      newRankName,
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
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
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
						_, _ = s.repo.UpsertReputation(resp.ResponderID, totalXP, 1)
					}
				}
				// Ubah status relawan menjadi canceled (oleh sistem/instansi)
				_ = s.repo.AgencyReviewVolunteer(incidentID, resp.ResponderID, false)
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
