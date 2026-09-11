package telemetry

import (
	"encoding/json"
	"sync"
	"testing"
	"time"

	"github.com/bytedance/sonic"
	"github.com/stretchr/testify/assert"
)

func TestLocationRequestPool_AcquireAndRelease(t *testing.T) {
	req := AcquireLocationUpdateRequest()
	assert.NotNil(t, req)
	assert.Equal(t, float64(0), req.Latitude)
	assert.Equal(t, float64(0), req.Longitude)

	req.Latitude = -6.2088
	req.Longitude = 106.8456
	req.Accuracy = 5.0
	req.Speed = 12.5
	req.Heading = 180.0

	ReleaseLocationUpdateRequest(req)

	// Acquire again and ensure clean zero state
	req2 := AcquireLocationUpdateRequest()
	assert.NotNil(t, req2)
	assert.Equal(t, float64(0), req2.Latitude)
	assert.Equal(t, float64(0), req2.Longitude)
	assert.Equal(t, float64(0), req2.Accuracy)
	assert.Equal(t, float64(0), req2.Speed)
	assert.Equal(t, float64(0), req2.Heading)

	ReleaseLocationUpdateRequest(req2)
}

func TestLocationRequestPool_ConcurrentAccess(t *testing.T) {
	const goroutines = 100
	const iterations = 500

	var wg sync.WaitGroup
	wg.Add(goroutines)

	for i := 0; i < goroutines; i++ {
		go func(id int) {
			defer wg.Done()
			for j := 0; j < iterations; j++ {
				req := AcquireLocationUpdateRequest()
				req.Latitude = float64(id) + 0.1
				req.Longitude = float64(j) + 0.2
				assert.NotZero(t, req.Latitude)
				ReleaseLocationUpdateRequest(req)
			}
		}(i)
	}

	wg.Wait()
}

func BenchmarkUpdateLocation_WithPool(b *testing.B) {
	sampleJSON := []byte(`{"latitude":-6.2087634,"longitude":106.845599,"accuracy":4.5,"speed":15.2,"heading":90.0}`)
	b.ReportAllocs()
	b.ResetTimer()

	for i := 0; i < b.N; i++ {
		req := AcquireLocationUpdateRequest()
		_ = sonic.Unmarshal(sampleJSON, req)
		_ = req.Latitude
		ReleaseLocationUpdateRequest(req)
	}
}

func BenchmarkUpdateLocation_WithoutPool(b *testing.B) {
	sampleJSON := []byte(`{"latitude":-6.2087634,"longitude":106.845599,"accuracy":4.5,"speed":15.2,"heading":90.0}`)
	b.ReportAllocs()
	b.ResetTimer()

	for i := 0; i < b.N; i++ {
		var req struct {
			Latitude  float64 `json:"latitude"`
			Longitude float64 `json:"longitude"`
			Accuracy  float64 `json:"accuracy"`
			Speed     float64 `json:"speed"`
			Heading   float64 `json:"heading"`
		}
		_ = json.Unmarshal(sampleJSON, &req)
		_ = req.Latitude
	}
}

func BenchmarkBroadcastPayload_Typed(b *testing.B) {
	b.ReportAllocs()
	b.ResetTimer()

	for i := 0; i < b.N; i++ {
		payload := LocationBroadcastPayload{
			UserID:    "00000000-0000-0000-0000-000000000001",
			Latitude:  -6.2087634,
			Longitude: 106.845599,
			Timestamp: time.Now().Unix(),
		}
		data, _ := sonic.Marshal(payload)
		_ = data
	}
}

func BenchmarkBroadcastPayload_MapInterface(b *testing.B) {
	b.ReportAllocs()
	b.ResetTimer()

	for i := 0; i < b.N; i++ {
		payload := map[string]interface{}{
			FieldUserID:    "00000000-0000-0000-0000-000000000001",
			FieldLatitude:  -6.2087634,
			FieldLongitude: 106.845599,
			FieldTimestamp: time.Now().Unix(),
		}
		data, _ := json.Marshal(payload)
		_ = data
	}
}
