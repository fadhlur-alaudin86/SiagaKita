package user

import "errors"

// Purpose: Defines standard typed sentinel errors for user and authentication lifecycle.
// Data & Logic Flow: Returned by repository and service methods, evaluated by handlers via errors.Is.
// Key Components: ErrNIKAlreadyUsed, ErrTokenReused.

var (
	// ErrNIKAlreadyUsed indicates the NIK has already been registered by another user profile.
	ErrNIKAlreadyUsed = errors.New("NIK_ALREADY_USED")

	// ErrEmailTaken indicates the email is already registered. Handlers map it
	// to 409 ERR_EMAIL_TAKEN with the dictionary message "Email sudah terdaftar".
	ErrEmailTaken = errors.New("ERR_EMAIL_TAKEN")

	// ErrTokenReused indicates a refresh token replay attack or an expired refresh token reuse.
	ErrTokenReused = errors.New("ERR_TOKEN_REUSED: Token refresh telah kedaluwarsa atau digunakan kembali")
)
