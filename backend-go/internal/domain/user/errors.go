package user

import "errors"

// Purpose: Defines standard typed sentinel errors for user and authentication lifecycle.
// Data & Logic Flow: Returned by repository and service methods, evaluated by handlers via errors.Is.
// Key Components: ErrNIKAlreadyUsed, ErrTokenReused.

var (
	// ErrNIKAlreadyUsed indicates the NIK has already been registered by another user profile.
	ErrNIKAlreadyUsed = errors.New("NIK_ALREADY_USED")

	// ErrTokenReused indicates a refresh token replay attack or an expired refresh token reuse.
	ErrTokenReused = errors.New("ERR_TOKEN_REUSED: Token refresh telah kedaluwarsa atau digunakan kembali")
)
