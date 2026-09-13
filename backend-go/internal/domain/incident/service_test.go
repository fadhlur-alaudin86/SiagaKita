package incident

import (
	"fmt"
	"os"
	"testing"
	"time"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func getTestDB() *gorm.DB {
	host := os.Getenv("DB_HOST")
	if host == "" {
		host = "localhost"
	}
	port := os.Getenv("DB_PORT")
	if port == "" {
		port = "5433"
	}
	user := os.Getenv("DB_USER")
	if user == "" {
		user = "siagakita_admin"
	}
	password := os.Getenv("DB_PASSWORD")
	if password == "" {
		password = "5566de1f136204174a3a34761d44f361e1d6299744e223609c71fe8ca8ac0978"
	}
	dbname := os.Getenv("DB_NAME")
	if dbname == "" {
		dbname = "siagakita"
	}

	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable connect_timeout=2",
		host, port, user, password, dbname)

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		return nil
	}
	sqlDB, err := db.DB()
	if err != nil || sqlDB.Ping() != nil {
		return nil
	}
	return db
}

func TestValidIncidentTypes(t *testing.T) {
	validTypes := []string{"medical", "fire", "crime", "rescue", "accident", "disaster", "general"}
	for _, it := range validTypes {
		if !validIncidentTypes[it] {
			t.Errorf("expected '%s' to be valid incident type", it)
		}
	}

	invalidTypes := []string{"hooligan", "ufo", "prank", "unknown", "invalid"}
	for _, it := range invalidTypes {
		if validIncidentTypes[it] {
			t.Errorf("expected '%s' to be invalid incident type", it)
		}
	}
}

func TestIncidentTypeMultipliers(t *testing.T) {
	expectedMultipliers := map[string]float64{
		"medical":  1.5,
		"fire":     1.3,
		"rescue":   1.4,
		"crime":    1.2,
		"accident": 1.3,
		"disaster": 1.4,
		"general":  1.0,
		"unknown":  1.0,
	}

	for it, expected := range expectedMultipliers {
		actual, ok := incidentTypeMultiplier[it]
		if !ok {
			t.Fatalf("multiplier for '%s' missing", it)
		}
		if actual != expected {
			t.Errorf("expected multiplier for '%s' to be %f, got %f", it, expected, actual)
		}
	}
}

func TestUpdateType_InvalidType(t *testing.T) {
	svc := &Service{}
	err := svc.UpdateType("inc-123", "user-123", "unregistered_type")
	if err == nil {
		t.Fatal("expected error for invalid incident type, got nil")
	}
	expected := "tipe insiden tidak valid: unregistered_type"
	if err.Error() != expected {
		t.Errorf("expected error '%s', got '%s'", expected, err.Error())
	}
}

func TestTriggerSOS_AtomicBroadcast(t *testing.T) {
	db := getTestDB()
	if db == nil {
		t.Skip("PostgreSQL test database unavailable, skipping integration tests")
	}

	repo := NewRepository(db)
	svc := NewService(repo, nil)

	broadcastTriggered := false
	var broadcastIncidentID string
	svc.OnBroadcast = func(incidentID string) {
		broadcastTriggered = true
		broadcastIncidentID = incidentID
	}

	var testUserID string
	if err := db.Raw("SELECT id FROM users WHERE role = 'civilian' LIMIT 1").Scan(&testUserID).Error; err != nil || testUserID == "" {
		t.Skip("No civilian user found in test database, skipping test")
	}
	db.Exec("UPDATE incidents SET status = 'resolved' WHERE reporter_id = ? AND status IN ('grace_period', 'broadcasting', 'handling')", testUserID)

	req := &TriggerSOSRequest{
		Latitude:        -6.2088,
		Longitude:       106.8456,
		AddressDetail:   "Jl. Sudirman No. 1, Jakarta",
		IncidentType:    "medical",
		SkipGracePeriod: true,
	}

	resp, err := svc.TriggerSOS(testUserID, req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if resp.Status != StatusBroadcasting {
		t.Errorf("expected status '%s', got '%s'", StatusBroadcasting, resp.Status)
	}
	if resp.IncidentType != "medical" {
		t.Errorf("expected incident type 'medical', got '%s'", resp.IncidentType)
	}
	if !broadcastTriggered || broadcastIncidentID != resp.IncidentID {
		t.Errorf("expected OnBroadcast to be triggered with ID '%s'", resp.IncidentID)
	}

	inc, err := repo.FindByID(resp.IncidentID)
	if err != nil {
		t.Fatalf("failed to query created incident: %v", err)
	}
	if inc.Status != StatusBroadcasting {
		t.Errorf("expected DB status '%s', got '%s'", StatusBroadcasting, inc.Status)
	}
	if inc.IncidentType != "medical" {
		t.Errorf("expected DB incident type 'medical', got '%s'", inc.IncidentType)
	}

	db.Exec("DELETE FROM incidents WHERE id = ?", resp.IncidentID)
}

func TestUpdateType_EarlyBroadcasting(t *testing.T) {
	db := getTestDB()
	if db == nil {
		t.Skip("PostgreSQL test database unavailable, skipping integration tests")
	}

	repo := NewRepository(db)
	svc := NewService(repo, nil)
	var testUserID string
	if err := db.Raw("SELECT id FROM users WHERE role = 'civilian' LIMIT 1").Scan(&testUserID).Error; err != nil || testUserID == "" {
		t.Skip("No civilian user found in test database, skipping test")
	}
	db.Exec("UPDATE incidents SET status = 'resolved' WHERE reporter_id = ? AND status IN ('grace_period', 'broadcasting', 'handling')", testUserID)

	inc := &Incident{
		ReporterID:   testUserID,
		Latitude:     -6.2088,
		Longitude:    106.8456,
		IncidentType: IncidentTypeUnknown,
		Status:       StatusBroadcasting,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}
	if err := repo.CreateIncident(inc); err != nil {
		t.Fatalf("failed to create incident: %v", err)
	}
	defer db.Exec("DELETE FROM incidents WHERE id = ?", inc.ID)

	// Case 1: Updating unknown to fire within 30s should succeed
	err := svc.UpdateType(inc.ID, testUserID, "fire")
	if err != nil {
		t.Fatalf("expected UpdateType to succeed during early broadcasting, got: %v", err)
	}

	updated, err := repo.FindByID(inc.ID)
	if err != nil || updated.IncidentType != "fire" {
		t.Errorf("expected incident type to be 'fire', got '%s'", updated.IncidentType)
	}

	// Case 2: Updating again when already identified (not unknown) should fail
	err = svc.UpdateType(inc.ID, testUserID, "crime")
	if err == nil {
		t.Fatal("expected error when updating already-identified incident type, got nil")
	}
}
