package database

import (
	"fmt"
	"io/fs"
	"testing"

	"siagakita-backend/migrations"

	"github.com/golang-migrate/migrate/v4/source/iofs"
)

func TestMigrationsEmbeddedDiscovery(t *testing.T) {
	// Verify that migrations.FS can be mounted as an iofs driver
	driver, err := iofs.New(migrations.FS, ".")
	if err != nil {
		t.Fatalf("failed to initialize iofs driver from embedded migrations: %v", err)
	}

	firstVersion, err := driver.First()
	if err != nil {
		t.Fatalf("failed to get first migration version: %v", err)
	}
	if firstVersion != 1 {
		t.Errorf("expected first migration version to be 1, got %d", firstVersion)
	}

	// Verify all sequential migrations exist from 1 to 20
	for i := 1; i <= 20; i++ {
		upName := fmt.Sprintf("%03d_*.up.sql", i)
		matches, err := fs.Glob(migrations.FS, upName)
		if err != nil {
			t.Fatalf("fs.Glob error for %s: %v", upName, err)
		}
		if len(matches) == 0 {
			t.Errorf("missing .up.sql migration for version %d (pattern: %s)", i, upName)
		}

		downName := fmt.Sprintf("%03d_*.down.sql", i)
		matchesDown, err := fs.Glob(migrations.FS, downName)
		if err != nil {
			t.Fatalf("fs.Glob error for %s: %v", downName, err)
		}
		if len(matchesDown) == 0 {
			t.Errorf("missing .down.sql rollback migration for version %d (pattern: %s)", i, downName)
		}
	}
}

func TestMigrationFileContentNotEmpty(t *testing.T) {
	entries, err := fs.ReadDir(migrations.FS, ".")
	if err != nil {
		t.Fatalf("failed to read embedded migrations directory: %v", err)
	}

	if len(entries) < 40 {
		t.Errorf("expected at least 40 migration files (20 up + 20 down), found %d entries", len(entries))
	}

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		data, err := fs.ReadFile(migrations.FS, entry.Name())
		if err != nil {
			t.Errorf("failed to read embedded file %s: %v", entry.Name(), err)
		}
		if len(data) == 0 {
			t.Errorf("migration file %s is unexpectedly empty", entry.Name())
		}
	}
}
