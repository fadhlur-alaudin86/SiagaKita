package main

import (
	"fmt"
	"os"
	"strconv"

	"siagakita-backend/internal/config"
	"siagakita-backend/internal/database"
	"siagakita-backend/internal/utils"
)

func printUsage() {
	fmt.Println("SiagaKita Database Migration Utility")
	fmt.Println()
	fmt.Println("Usage:")
	fmt.Println("  siagakita-migrate <command> [arguments]")
	fmt.Println()
	fmt.Println("Commands:")
	fmt.Println("  up              Apply all pending migrations")
	fmt.Println("  down [steps]    Rollback the database by N steps (default: 1)")
	fmt.Println("  version         Display the active schema migration version and dirty status")
	fmt.Println("  force <version> Reset the dirty migration state to a specific version number")
	fmt.Println("  help            Display this help menu")
	fmt.Println()
	fmt.Println("Examples:")
	fmt.Println("  siagakita-migrate up")
	fmt.Println("  siagakita-migrate down 1")
	fmt.Println("  siagakita-migrate version")
	fmt.Println("  siagakita-migrate force 18")
}

func main() {
	// Initialize logger
	utils.InitLogger(os.Getenv("GO_ENV") == "production")

	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	command := os.Args[1]

	// Handle help without DB connection
	if command == "help" || command == "-h" || command == "--help" {
		printUsage()
		os.Exit(0)
	}

	cfg := config.Load()
	db := database.NewPostgres(cfg)
	sqlDB, err := db.DB()
	if err != nil {
		utils.Fatal().Err(err).Msg("[Migrate-CLI] Failed to acquire database handle")
	}
	defer func() {
		if err := sqlDB.Close(); err != nil {
			utils.Error().Err(err).Msg("[Migrate-CLI] Failed to close database connection")
		}
	}()

	switch command {
	case "up":
		if err := database.AutoMigrate(sqlDB); err != nil {
			utils.Fatal().Err(err).Msg("[Migrate-CLI] Up migration failed")
		}
		fmt.Println("✅ Database schema migrated up successfully.")

	case "down":
		steps := 1
		if len(os.Args) >= 3 {
			parsedSteps, err := strconv.Atoi(os.Args[2])
			if err != nil || parsedSteps <= 0 {
				fmt.Printf("❌ Invalid steps count '%s'. Must be a positive integer.\n", os.Args[2])
				os.Exit(1)
			}
			steps = parsedSteps
		}

		if err := database.MigrateDown(sqlDB, steps); err != nil {
			utils.Fatal().Err(err).Msg("[Migrate-CLI] Rollback failed")
		}
		fmt.Printf("✅ Rolled back %d migration step(s) successfully.\n", steps)

	case "version":
		version, dirty, err := database.GetMigrationVersion(sqlDB)
		if err != nil {
			utils.Fatal().Err(err).Msg("[Migrate-CLI] Failed to retrieve migration version")
		}
		fmt.Printf("Active Schema Version: %d (Dirty: %t)\n", version, dirty)

	case "force":
		if len(os.Args) < 3 {
			fmt.Println("❌ Usage: siagakita-migrate force <version>")
			os.Exit(1)
		}
		targetVersion, err := strconv.Atoi(os.Args[2])
		if err != nil || targetVersion < 0 {
			fmt.Printf("❌ Invalid version '%s'. Must be a non-negative integer.\n", os.Args[2])
			os.Exit(1)
		}

		if err := database.MigrateForce(sqlDB, targetVersion); err != nil {
			utils.Fatal().Err(err).Msg("[Migrate-CLI] Force version failed")
		}
		fmt.Printf("✅ Forced migration version to %d.\n", targetVersion)

	default:
		fmt.Printf("❌ Unknown command '%s'\n\n", command)
		printUsage()
		os.Exit(1)
	}
}
