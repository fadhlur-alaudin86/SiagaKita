package agency

import "fmt"

type Service struct {
	repo *Repository
}

func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
}

// CreatePersonnel creates a new field personnel account attached to an agency.
func (s *Service) CreatePersonnel(req *CreatePersonnelRequest, agencyUserID string) error {
	if req.Email == "" || req.Password == "" || req.FullName == "" || req.BadgeNumber == "" {
		return fmt.Errorf("semua field (email, password, full_name, badge_number) wajib diisi")
	}

	// Get the corresponding agency ID for this agency user
	agencyID, err := s.repo.GetAgencyIDByUser(agencyUserID)
	if err != nil {
		return err
	}

	return s.repo.CreatePersonnel(req, agencyID)
}
