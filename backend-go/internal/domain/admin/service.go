package admin

import "gorm.io/gorm"

// Service contains business logic for the admin domain.
type Service struct {
	repo *Repository
}

func NewService(db *gorm.DB) *Service {
	return &Service{repo: NewRepository(db)}
}

// ─── KYC ──────────────────────────────────────────────────────────────────────

func (s *Service) GetPendingKYC() ([]VolunteerKYC, error) {
	return s.repo.GetPendingKYC()
}

func (s *Service) ApproveKYC(userID, verifiedBy string) error {
	return s.repo.ApproveKYC(userID, verifiedBy)
}

func (s *Service) RejectKYC(userID, verifiedBy, reason string) error {
	if reason == "" {
		reason = "Tidak memenuhi syarat"
	}
	return s.repo.RejectKYC(userID, verifiedBy, reason)
}

// ─── User Management ──────────────────────────────────────────────────────────

func (s *Service) CreateAdmin(req *CreateAdminRequest, superadminID string) error {
	if req.Email == "" || req.Password == "" || req.FullName == "" {
		return errorMsg("Email, password, dan full name wajib diisi")
	}
	return s.repo.CreateAdmin(req, superadminID)
}

func (s *Service) CreateAgency(req *CreateAgencyRequest) error {
	if req.Email == "" || req.Password == "" || req.Name == "" || req.Type == "" || req.CityCode == "" {
		return errorMsg("Email, password, name, type, dan city_code wajib diisi")
	}
	// Validasi Enum Type
	validTypes := map[string]bool{"police": true, "fire": true, "medical": true, "sar": true}
	if !validTypes[req.Type] {
		return errorMsg("Tipe instansi tidak valid (harus police/fire/medical/sar)")
	}

	return s.repo.CreateAgency(req)
}

func (s *Service) GetUsers(filterBanned bool, filterHighStrike bool, search string, role string) ([]AdminUserItem, error) {
	return s.repo.GetUsers(filterBanned, filterHighStrike, search, role)
}

func (s *Service) GetUserDetail(userID string) (*UserDetailResponse, error) {
	return s.repo.GetUserDetail(userID)
}

func (s *Service) BanUser(userID string, req *BanUserRequest, callerID string) error {
	return s.repo.BanUser(userID, req, callerID)
}

func (s *Service) UnbanUser(userID string, callerID string) error {
	return s.repo.UnbanUser(userID, callerID)
}

func (s *Service) ResetStrike(userID string, callerID string) error {
	return s.repo.ResetStrike(userID, callerID)
}

// ─── KYC Warga ────────────────────────────────────────────────────────

func (s *Service) GetPendingWargaKYC() ([]WargaKYCItem, error) {
	return s.repo.GetPendingWargaKYC()
}

func (s *Service) ApproveWargaKYC(userID string) error {
	return s.repo.ApproveWargaKYC(userID)
}

func (s *Service) RejectWargaKYC(userID string) error {
	return s.repo.RejectWargaKYC(userID)
}

// ─── Agency & Admin Listings ─────────────────────────────────────────────────

func (s *Service) GetAgencies() ([]AgencyItem, error) {
	return s.repo.GetAgencies()
}

func (s *Service) GetAdmins() ([]AdminItem, error) {
	return s.repo.GetAdmins()
}

// ─── Ranks ────────────────────────────────────────────────────────────────────

func (s *Service) GetRanks() ([]MRank, error) {
	return s.repo.GetRanks()
}

func (s *Service) CreateRank(req *RankRequest) (*MRank, error) {
	if req.RankName == "" {
		return nil, errorMsg("rank_name wajib diisi")
	}
	if req.MinExp < 0 {
		return nil, errorMsg("min_exp tidak boleh negatif")
	}
	return s.repo.CreateRank(req)
}

func (s *Service) UpdateRank(id int, req *RankRequest) (*MRank, error) {
	if req.RankName == "" {
		return nil, errorMsg("rank_name wajib diisi")
	}
	return s.repo.UpdateRank(id, req)
}

func (s *Service) DeleteRank(id int) error {
	return s.repo.DeleteRank(id)
}

// ─── Stats ────────────────────────────────────────────────────────────────────

func (s *Service) GetStats(period string) (*StatsResponse, error) {
	return s.repo.GetStats(period)
}

// ─── Badges (Peringkat Relawan) ────────────────────────────────────────────────

func (s *Service) GetBadges() ([]MBadge, error) {
	return s.repo.FindAllBadges()
}

func (s *Service) CreateBadge(req *BadgeRequest) (*MBadge, error) {
	if req.BadgeName == "" {
		return nil, errorMsg("badge_name wajib diisi")
	}
	badge := &MBadge{
		BadgeName:   req.BadgeName,
		Description: req.Description,
		IconURL:     req.IconURL,
	}
	err := s.repo.CreateBadge(badge)
	return badge, err
}

func (s *Service) UpdateBadge(id string, req *BadgeRequest) (*MBadge, error) {
	if req.BadgeName == "" {
		return nil, errorMsg("badge_name wajib diisi")
	}
	err := s.repo.UpdateBadge(id, req)
	if err != nil {
		return nil, err
	}
	return &MBadge{ID: id, BadgeName: req.BadgeName, Description: req.Description, IconURL: req.IconURL}, nil
}

func (s *Service) DeleteBadge(id string) error {
	return s.repo.DeleteBadge(id)
}

// ─── Helper ───────────────────────────────────────────────────────────────────

type serviceError struct{ msg string }

func (e *serviceError) Error() string { return e.msg }

func errorMsg(msg string) error { return &serviceError{msg: msg} }
