package agency

// CreatePersonnelRequest adalah request body untuk membuat akun personil lapangan.
type CreatePersonnelRequest struct {
	Email       string `json:"email"`
	Password    string `json:"password"`
	FullName    string `json:"full_name"`
	BadgeNumber string `json:"badge_number"`
}

type Agency struct {
	ID            string   `json:"id" gorm:"column:id;primaryKey;default:gen_random_uuid()"`
	Name          string   `json:"name" gorm:"column:name"`
	Type          string   `json:"type" gorm:"column:type"`
	CityCode      string   `json:"city_code" gorm:"column:city_code"`
	HotlineNumber *string  `json:"hotline_number" gorm:"column:hotline_number"`
	Latitude      *float64 `json:"latitude" gorm:"column:latitude"`
	Longitude     *float64 `json:"longitude" gorm:"column:longitude"`
	AccountID     string   `json:"account_id" gorm:"column:account_id"`
}
