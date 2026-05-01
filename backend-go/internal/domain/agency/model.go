package agency

// CreatePersonnelRequest adalah request body untuk membuat akun personil lapangan.
type CreatePersonnelRequest struct {
	Email       string `json:"email"`
	Password    string `json:"password"`
	FullName    string `json:"full_name"`
	BadgeNumber string `json:"badge_number"`
}
