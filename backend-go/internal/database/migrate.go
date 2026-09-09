package database

import (
	"database/sql"
	"errors"
	"fmt"
	"siagakita-backend/internal/utils"
	"siagakita-backend/migrations"

	"github.com/golang-migrate/migrate/v4"
	"github.com/golang-migrate/migrate/v4/database/postgres"
	"github.com/golang-migrate/migrate/v4/source/iofs"
)

// NewMigrator initializes a new golang-migrate instance using the embedded migration scripts and the provided database connection.
func NewMigrator(sqlDB *sql.DB) (*migrate.Migrate, error) {
	sourceDriver, err := iofs.New(migrations.FS, ".")
	if err != nil {
		return nil, fmt.Errorf("failed to create iofs migration driver: %w", err)
	}

	dbDriver, err := postgres.WithInstance(sqlDB, &postgres.Config{
		MigrationsTable: "schema_migrations",
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create postgres migration driver: %w", err)
	}

	m, err := migrate.NewWithInstance("iofs", sourceDriver, "postgres", dbDriver)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize migrator: %w", err)
	}

	return m, nil
}

// AutoMigrate runs all pending migrations UP automatically during application startup.
func AutoMigrate(sqlDB *sql.DB) error {
	m, err := NewMigrator(sqlDB)
	if err != nil {
		return err
	}

	currentVersion, dirty, err := m.Version()
	if err != nil && !errors.Is(err, migrate.ErrNilVersion) {
		utils.Warn().Err(err).Msg("[Migrate] Could not determine active migration version")
	} else if errors.Is(err, migrate.ErrNilVersion) {
		utils.Info().Msg("[Migrate] Fresh database detected (version: nil)")
	} else {
		utils.Info().Uint("version", currentVersion).Bool("dirty", dirty).Msg("[Migrate] Active database migration status")
		if dirty {
			return fmt.Errorf("database migration is in a DIRTY state at version %d. Please resolve manually using siagakita-migrate force <version>", currentVersion)
		}
	}

	err = m.Up()
	if err != nil && !errors.Is(err, migrate.ErrNoChange) {
		return fmt.Errorf("auto-migration failed: %w", err)
	}

	if errors.Is(err, migrate.ErrNoChange) {
		utils.Info().Msg("[Migrate] Database schema is up to date (no new migrations)")
	} else {
		newVersion, _, _ := m.Version()
		utils.Info().Uint("new_version", newVersion).Msg("[Migrate] Successfully applied pending migrations")
	}

	return nil
}

// MigrateDown rolls back the database by the specified number of steps.
func MigrateDown(sqlDB *sql.DB, steps int) error {
	m, err := NewMigrator(sqlDB)
	if err != nil {
		return err
	}

	if steps <= 0 {
		steps = 1
	}

	currentVersion, dirty, _ := m.Version()
	if dirty {
		return fmt.Errorf("database is in a dirty state at version %d; rollback aborted", currentVersion)
	}

	utils.Info().Uint("current_version", currentVersion).Int("steps", steps).Msg("[Migrate] Rolling back database schema")
	err = m.Steps(-steps)
	if err != nil && !errors.Is(err, migrate.ErrNoChange) {
		return fmt.Errorf("migration rollback failed: %w", err)
	}

	newVersion, _, _ := m.Version()
	utils.Info().Uint("new_version", newVersion).Msg("[Migrate] Rollback completed successfully")
	return nil
}

// MigrateForce resets the dirty flag at the given version.
func MigrateForce(sqlDB *sql.DB, version int) error {
	m, err := NewMigrator(sqlDB)
	if err != nil {
		return err
	}

	utils.Info().Int("target_version", version).Msg("[Migrate] Forcing migration version to clear dirty state")
	if err := m.Force(version); err != nil {
		return fmt.Errorf("force migration version failed: %w", err)
	}

	utils.Info().Int("target_version", version).Msg("[Migrate] Successfully forced version")
	return nil
}

// GetMigrationVersion returns the current schema version and dirty state.
func GetMigrationVersion(sqlDB *sql.DB) (uint, bool, error) {
	m, err := NewMigrator(sqlDB)
	if err != nil {
		return 0, false, err
	}
	return m.Version()
}
