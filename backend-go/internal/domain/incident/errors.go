package incident

import "errors"

// Purpose: Defines standard typed sentinel errors for incident and reporting lifecycle.
// Data & Logic Flow: Returned by repository and service methods, evaluated by handlers via errors.Is.
// Key Components: ErrUnauthorized, ErrIncidentConflict, ErrReportNotFound, ErrReportCannotBeCanceled, ErrSOSBanned.

var (
	// ErrUnauthorized indicates the user is not permitted to modify or cancel the incident/report.
	ErrUnauthorized = errors.New("unauthorized")

	// ErrIncidentConflict indicates the incident is in a state where cancellation or modification is rejected.
	ErrIncidentConflict = errors.New("conflict: incident cannot be canceled at its current status")

	// ErrReportNotFound indicates the citizen report was not found.
	ErrReportNotFound = errors.New("laporan tidak ditemukan")

	// ErrReportCannotBeCanceled indicates the report status is past the allowable cancellation state.
	ErrReportCannotBeCanceled = errors.New("hanya laporan dengan status 'sent' atau 'pending' yang dapat dibatalkan")

	// ErrSOSBanned indicates the user account has been disabled from triggering SOS due to prior violations.
	ErrSOSBanned = errors.New("sos_banned: akun Anda dinonaktifkan dari fitur SOS karena pelanggaran berulang")
)
