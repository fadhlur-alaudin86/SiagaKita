package database

import (
	"fmt"
	"siagakita-backend/internal/utils"

	"siagakita-backend/internal/config"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// NewPostgres creates and returns a GORM DB connection pool.
func NewPostgres(cfg *config.Config) *gorm.DB {
	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=disable TimeZone=Asia/Jakarta",
		cfg.DBHost, cfg.DBPort, cfg.DBUser, cfg.DBPassword, cfg.DBName,
	)

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	})
	if err != nil {
		utils.Fatal().Err(err).Msg("[DB] Failed to connect to PostgreSQL")
	}

	sqlDB, err := db.DB()
	if err != nil {
		utils.Fatal().Err(err).Msg("[DB] Failed to get underlying sql.DB")
	}
	sqlDB.SetMaxOpenConns(25)
	sqlDB.SetMaxIdleConns(10)

	utils.Info().Msg("[DB] PostgreSQL connected successfully")
	return db
}
