package telemetry

import (
	"sync"
)

// LocationUpdateRequest represents the incoming telemetry coordinates from a volunteer.
type LocationUpdateRequest struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
	Accuracy  float64 `json:"accuracy,omitempty"`
	Speed     float64 `json:"speed,omitempty"`
	Heading   float64 `json:"heading,omitempty"`
}

// Reset clears all fields of the LocationUpdateRequest.
func (r *LocationUpdateRequest) Reset() {
	r.Latitude = 0
	r.Longitude = 0
	r.Accuracy = 0
	r.Speed = 0
	r.Heading = 0
}

// locationRequestPool manages a pool of LocationUpdateRequest structs to reduce GC allocations.
var locationRequestPool = sync.Pool{
	New: func() any {
		return new(LocationUpdateRequest)
	},
}

// AcquireLocationUpdateRequest acquires a recycled LocationUpdateRequest from the pool.
func AcquireLocationUpdateRequest() *LocationUpdateRequest {
	req := locationRequestPool.Get().(*LocationUpdateRequest)
	req.Reset()
	return req
}

// ReleaseLocationUpdateRequest resets and returns a LocationUpdateRequest to the pool.
func ReleaseLocationUpdateRequest(req *LocationUpdateRequest) {
	if req != nil {
		req.Reset()
		locationRequestPool.Put(req)
	}
}

// LocationBroadcastPayload represents the typed payload broadcast to online dispatchers/admins via WebSocket.
// Using a concrete struct eliminates map allocations and interface boxing during high-frequency ingestion.
type LocationBroadcastPayload struct {
	UserID    string  `json:"user_id"`
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
	Timestamp int64   `json:"timestamp"`
}
