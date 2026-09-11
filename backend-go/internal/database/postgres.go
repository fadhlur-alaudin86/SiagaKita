package database

import (
	"context"
	"fmt"
	"time"

	"siagakita-backend/internal/config"
	"siagakita-backend/internal/utils"

	"github.com/jackc/pgx/v5/pgxpool"
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

// NewPgxPool creates and returns a native pgx connection pool (jackc/pgx/v5/pgxpool).
// Dedicated to high-throughput raw queries (e.g. FindNearby, GPS telemetry hotpaths)
// operating alongside GORM in a dual-driver architecture.
func NewPgxPool(ctx context.Context, cfg *config.Config) *pgxpool.Pool {
	connStr := fmt.Sprintf(
		"postgres://%s:%s@%s:%s/%s?sslmode=disable",
		cfg.DBUser, cfg.DBPassword, cfg.DBHost, cfg.DBPort, cfg.DBName,
	)

	poolConfig, err := pgxpool.ParseConfig(connStr)
	if err != nil {
		utils.Fatal().Err(err).Msg("[DB] Failed to parse pgxpool config")
	}

	poolConfig.MaxConns = cfg.DBMaxConns
	poolConfig.MinConns = cfg.DBMinConns
	poolConfig.MaxConnLifetime = cfg.DBMaxConnLifetime
	poolConfig.MaxConnIdleTime = cfg.DBMaxConnIdleTime

	pool, err := pgxpool.NewWithConfig(ctx, poolConfig)
	if err != nil {
		utils.Fatal().Err(err).Msg("[DB] Failed to initialize pgxpool")
	}

	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if err := pool.Ping(pingCtx); err != nil {
		utils.Warn().Err(err).Msg("[DB] Initial pgxpool ping failed (will retry on demand)")
	} else {
		utils.Info().Msg("[DB] pgxpool connected successfully")
	}

	return pool
}
