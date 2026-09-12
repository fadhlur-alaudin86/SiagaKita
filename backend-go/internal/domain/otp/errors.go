package otp

import "errors"

// Purpose: Defines standard typed sentinel errors for OTP verification and rate-limiting.
// Data & Logic Flow: Returned by OTP service methods upon validation failures and handled via errors.Is.
// Key Components: ErrCooldown, ErrInvalidOTP.

var (
	// ErrCooldown indicates a user must wait before requesting a new OTP code.
	ErrCooldown = errors.New("Tunggu 1 menit sebelum meminta kode baru") //nolint:staticcheck

	// ErrInvalidOTP indicates the provided OTP code does not match the stored code.
	ErrInvalidOTP = errors.New("Kode OTP salah") //nolint:staticcheck
)
