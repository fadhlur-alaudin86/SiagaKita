package admin

import "errors"

// Purpose: Defines standard typed sentinel errors for admin gamification and management operations.
// Data & Logic Flow: Returned by repository and service methods upon entity lookup failures and evaluated by handlers via errors.Is.
// Key Components: ErrRankNotFound.

var (
	// ErrRankNotFound indicates that the requested reputation rank ID does not exist in the database.
	ErrRankNotFound = errors.New("rank tidak ditemukan")
)
