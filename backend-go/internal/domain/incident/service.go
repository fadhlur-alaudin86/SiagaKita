package incident

import (
	"errors"
	"fmt"
	"math"
	"time"

	"github.com/lib/pq"
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
}

func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
}

// ─── TriggerSOS (Jalur A) ─────────────────────────────────────────────────────

func (s *Service) TriggerSOS(reporterID string, req *TriggerSOSRequest, trustLabel string) (*TriggerSOSResponse, error) {
	banned, err := s.repo.IsSOSBanned(reporterID)
	if err != nil {
		return nil, err
	}
	if banned {
		return nil, errors.New("sos_banned: akun Anda dinonaktifkan dari fitur SOS karena pelanggaran berulang")
	}

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
	return &ActiveIncidentResponse{
		IncidentID:         inc.ID,
		Status:             inc.Status,
		IncidentType:       inc.IncidentType,
		Latitude:           inc.Latitude,
		Longitude:          inc.Longitude,
		ReporterTrustLabel: inc.ReporterTrustLabel,
		CreatedAt:          inc.CreatedAt.Format(time.RFC3339),
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

func (s *Service) UpdateReportStatus(id, status string) error {
	return s.repo.UpdateReportStatus(id, status)
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
func (s *Service) GetNearby(lat, lng, radiusKm float64) ([]NearbyIncidentResponse, error) {
	results, err := s.repo.FindNearby(lat, lng, radiusKm)
	if err != nil {
		return nil, err
	}
	if results == nil {
		results = []NearbyIncidentResponse{}
	}
	return results, nil
}

// AcceptIncident — relawan menerima SOS, buat record response + update status incident.
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

