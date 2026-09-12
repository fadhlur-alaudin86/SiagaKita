package main

import (
	"fmt"
	"os"
	"testing"
	"time"

	"siagakita-backend/internal/config"
	userDomain "siagakita-backend/internal/domain/user"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func getOptionalTestDB() *gorm.DB {
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

func TestSeedSuperAdmin_EmptyCredentials(t *testing.T) {
	cfg := &config.Config{
		SuperAdminEmail: "",
		SuperAdminPass:  "",
	}

	// Should safely return nil without attempting database calls
	err := seedSuperAdmin(nil, cfg)
	assert.NoError(t, err)

	cfg.SuperAdminEmail = "admin@example.com"
	cfg.SuperAdminPass = ""
	err = seedSuperAdmin(nil, cfg)
	assert.NoError(t, err)

	cfg.SuperAdminEmail = ""
	cfg.SuperAdminPass = "secret123"
	err = seedSuperAdmin(nil, cfg)
	assert.NoError(t, err)
}

func TestSeedSuperAdmin_WithLiveDB(t *testing.T) {
	db := getOptionalTestDB()
	if db == nil {
		t.Skip("Live test database not reachable; skipping superadmin integration tests")
	}

	testEmail := "test-superadmin@siagakita.com"
	testPass1 := "InitialSuperSecret123!"
	testPass2 := "UpdatedSuperSecret456!"

	// Cleanup any existing superadmin created during previous test runs
	defer func() {
		var u userDomain.User
		if err := db.Where("email = ? OR email = ?", testEmail, "updated-"+testEmail).First(&u).Error; err == nil {
			db.Exec("DELETE FROM admin_profiles WHERE user_id = ?", u.ID)
			db.Exec("DELETE FROM users WHERE id = ?", u.ID)
		}
	}()

	// 1. Initial creation
	cfg := &config.Config{
		SuperAdminEmail: testEmail,
		SuperAdminPass:  testPass1,
	}

	err := seedSuperAdmin(db, cfg)
	require.NoError(t, err)

	var created userDomain.User
	err = db.Where("role = 'superadmin' AND email = ?", testEmail).First(&created).Error
	require.NoError(t, err)
	assert.Equal(t, testEmail, created.Email)
	assert.Equal(t, "superadmin", created.Role)

	// Verify bcrypt hash matches pass1
	err = bcrypt.CompareHashAndPassword([]byte(created.PasswordHash), []byte(testPass1))
	assert.NoError(t, err)

	// Verify admin_profiles record exists with "root"
	var ap struct {
		UserID   string
		FullName string
	}
	err = db.Table("admin_profiles").Where("user_id = ?", created.ID).First(&ap).Error
	require.NoError(t, err)
	assert.Equal(t, "root", ap.FullName)

	// 2. Idempotent update: update password
	cfg.SuperAdminPass = testPass2
	err = seedSuperAdmin(db, cfg)
	require.NoError(t, err)

	var updated userDomain.User
	err = db.Where("id = ?", created.ID).First(&updated).Error
	require.NoError(t, err)
	assert.Equal(t, testEmail, updated.Email)

	// Verify bcrypt hash matches pass2 now
	err = bcrypt.CompareHashAndPassword([]byte(updated.PasswordHash), []byte(testPass2))
	assert.NoError(t, err)

	// 3. Ensure no duplicate superadmin rows were created
	var count int64
	db.Model(&userDomain.User{}).Where("role = 'superadmin' AND deleted_at IS NULL").Count(&count)
	assert.Equal(t, int64(1), count)
}

func TestNewFiberConfig_Timeouts(t *testing.T) {
	cfg := newFiberConfig()
	assert.Equal(t, 15*time.Second, cfg.ReadTimeout)
	assert.Equal(t, 15*time.Second, cfg.WriteTimeout)
	assert.Equal(t, 120*time.Second, cfg.IdleTimeout)
	assert.Equal(t, "SiagaKita API v1", cfg.AppName)
	assert.Equal(t, 15*1024*1024, cfg.BodyLimit)
}
