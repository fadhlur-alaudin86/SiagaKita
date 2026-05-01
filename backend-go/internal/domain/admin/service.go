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

func (s *Service) GetUsers(filterBanned bool, filterHighStrike bool, search string) ([]AdminUserItem, error) {
	return s.repo.GetUsers(filterBanned, filterHighStrike, search)
}

func (s *Service) BanUser(userID, reason string) error {
	return s.repo.BanUser(userID, reason)
}

func (s *Service) UnbanUser(userID string) error {
	return s.repo.UnbanUser(userID)
}

func (s *Service) ResetStrike(userID string) error {
	return s.repo.ResetStrike(userID)
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

func (s *Service) GetStats() (*StatsResponse, error) {
	return s.repo.GetStats()
}

// ─── Helper ───────────────────────────────────────────────────────────────────

type serviceError struct{ msg string }

func (e *serviceError) Error() string { return e.msg }

func errorMsg(msg string) error { return &serviceError{msg: msg} }
