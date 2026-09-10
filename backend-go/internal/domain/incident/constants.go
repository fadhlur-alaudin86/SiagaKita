package incident

// WebSocket Event Constants
const (
	EventIncidentUpdated = "INCIDENT_UPDATED"
	EventSOSStatusUpdate = "SOS_STATUS_UPDATE"
)

// Incident Lifecycle Statuses
const (
	StatusGracePeriod = "grace_period"
	StatusCanceled    = "canceled"
	StatusResolved    = "resolved"
	StatusFalseAlarm  = "false_alarm"
	StatusHandled     = "handled"
	StatusHandling    = "handling"
)

// Agency Operational Statuses
const (
	AgencyStatusCanceled = "canceled"
	AgencyStatusHandling = "handling"
)

// Incident Types
const (
	IncidentTypeUnknown = "unknown"
)

// Actions for WebSocket and Audit payloads
const (
	ActionAgencyHandle      = "agency_handle"
	ActionAgencyReview      = "agency_review"
	ActionVolunteerComplete = "volunteer_complete"
	ActionResolved          = "resolved"
)

// Map and JSON field keys
const (
	FieldIncidentID   = "incident_id"
	FieldStatus       = "status"
	FieldAction       = "action"
	FieldLatitude     = "latitude"
	FieldLongitude    = "longitude"
	FieldCompletedAt  = "completed_at"
	FieldUpdatedAt    = "updated_at"
	FieldAgencyStatus = "agency_status"
	FieldIncidentType = "incident_type"
	FieldMessage      = "message"
	FieldUpdated      = "updated"
)

const (
	errUnauthorized = "unauthorized"
	extJPG          = ".jpg"
)
