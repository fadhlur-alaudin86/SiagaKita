package notification

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/redis/go-redis/v9"
	"siagakita-backend/internal/domain/user"
	"siagakita-backend/internal/utils"
)

// Service coordinates push notification generation, geofenced targeting, and delivery.
type Service struct {
	sender   Sender
	userRepo *user.Repository
	rdb      *redis.Client
}

func NewService(sender Sender, userRepo *user.Repository, rdb *redis.Client) *Service {
	return &Service{
		sender:   sender,
		userRepo: userRepo,
		rdb:      rdb,
	}
}

// BroadcastEmergencySOS sends high-priority emergency notifications to nearby verified volunteers and agency personnel.
func (s *Service) BroadcastEmergencySOS(ctx context.Context, incidentID, incidentType, address, reporterID string, lat, lon float64) error {
	if s.sender == nil || s.userRepo == nil {
		return nil
	}

	tokenSet := make(map[string]struct{})

	// 1. Target Tier 1: Verified volunteers within 10 km
	volunteerTokens := s.findNearbyVolunteerTokens(ctx, lat, lon, reporterID)
	for _, tok := range volunteerTokens {
		if strings.TrimSpace(tok) != "" {
			tokenSet[tok] = struct{}{}
		}
	}

	// 2. Target Tier 2: Active agency personnel within 20 km
	agencyTokens, err := s.userRepo.FindNearbyAgencyPersonnelTokens(lat, lon, 20.0)
	if err == nil {
		for _, tok := range agencyTokens {
			if strings.TrimSpace(tok) != "" {
				tokenSet[tok] = struct{}{}
			}
		}
	} else {
		utils.Warn().Err(err).Msg("[NotificationService] Failed to query nearby agency personnel tokens")
	}

	if len(tokenSet) == 0 {
		utils.Info().Str("incident_id", incidentID).Msg("[NotificationService] No target device tokens found for SOS broadcast")
		return nil
	}

	tokens := make([]string, 0, len(tokenSet))
	for tok := range tokenSet {
		tokens = append(tokens, tok)
	}

	// 3. Format emergency payload
	typeLabel := strings.ToUpper(incidentType)
	if typeLabel == "" {
		typeLabel = "DARURAT"
	}

	locLabel := address
	if locLabel == "" {
		locLabel = fmt.Sprintf("%.4f, %.4f", lat, lon)
	}

	payload := PushPayload{
		IncidentID:   incidentID,
		IncidentType: incidentType,
		Title:        fmt.Sprintf("PERINGATAN DARURAT: %s", typeLabel),
		Body:         fmt.Sprintf("Insiden darurat dilaporkan di %s. Buka peta segera untuk memberikan bantuan.", locLabel),
		Latitude:     fmt.Sprintf("%f", lat),
		Longitude:    fmt.Sprintf("%f", lon),
		Address:      address,
		ChannelID:    "emergency_alerts",
		Priority:     PriorityHigh,
		ClickAction:  "FLUTTER_NOTIFICATION_CLICK",
	}

	// 4. Send via multicast sender
	res, err := s.sender.SendMulticast(ctx, payload, tokens)
	if err != nil {
		return fmt.Errorf("gagal mengirim push notification: %w", err)
	}

	// 5. Asynchronously prune any stale/unregistered tokens detected by FCM
	if res != nil && len(res.StaleTokens) > 0 {
		go func(stale []string) {
			if pruneErr := s.userRepo.ClearStaleFCMTokens(stale); pruneErr != nil {
				utils.Error().Err(pruneErr).Int("count", len(stale)).Msg("[NotificationService] Failed to prune stale FCM tokens")
			} else {
				utils.Info().Int("count", len(stale)).Msg("[NotificationService] Successfully pruned stale FCM tokens")
			}
		}(res.StaleTokens)
	}

	return nil
}

// SendDirectMissionAssignment alerts official agency personnel of an explicit mission dispatch.
func (s *Service) SendDirectMissionAssignment(ctx context.Context, personnelUserID, incidentID, incidentType, address string, lat, lon float64) error {
	if s.sender == nil || s.userRepo == nil {
		return nil
	}

	token, err := s.userRepo.FindUserFCMToken(personnelUserID)
	if err != nil || strings.TrimSpace(token) == "" {
		return nil
	}

	payload := PushPayload{
		IncidentID:   incidentID,
		IncidentType: incidentType,
		Title:        "PENUGASAN MISI BARU",
		Body:         fmt.Sprintf("Anda telah ditugaskan untuk merespon insiden di %s.", address),
		Latitude:     fmt.Sprintf("%f", lat),
		Longitude:    fmt.Sprintf("%f", lon),
		Address:      address,
		ChannelID:    "emergency_alerts",
		Priority:     "high",
		ClickAction:  "FLUTTER_NOTIFICATION_CLICK",
	}

	res, err := s.sender.SendMulticast(ctx, payload, []string{token})
	if err != nil {
		return err
	}

	if res != nil && len(res.StaleTokens) > 0 {
		_ = s.userRepo.ClearFCMToken(personnelUserID)
	}

	return nil
}

// findNearbyVolunteerTokens queries Redis geospatial set "relawan:locations" within 10 km.
// Falls back to active verified volunteers in the database if Redis is unavailable or empty.
func (s *Service) findNearbyVolunteerTokens(ctx context.Context, lat, lon float64, excludeUserID string) []string {
	if s.rdb != nil {
		subCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
		defer cancel()

		geoRes, err := s.rdb.GeoSearch(subCtx, "relawan:locations", &redis.GeoSearchQuery{
			Longitude:  lon,
			Latitude:   lat,
			Radius:     10.0,
			RadiusUnit: "km",
			Count:      100,
		}).Result()

		if err == nil && len(geoRes) > 0 {
			tokens, dbErr := s.userRepo.FindVolunteerFCMTokensByIDs(geoRes, excludeUserID)
			if dbErr == nil && len(tokens) > 0 {
				return tokens
			}
		}
	}

	// Fallback to verified volunteers if geospatial lookup yields no members
	fallbackTokens, err := s.userRepo.FindAllVerifiedVolunteerFCMTokens(excludeUserID, 50)
	if err != nil {
		utils.Warn().Err(err).Msg("[NotificationService] Fallback volunteer token discovery failed")
		return nil
	}
	return fallbackTokens
}
