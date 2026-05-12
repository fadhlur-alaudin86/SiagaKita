package main

import (
	"context"
	"errors"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"

	"siagakita-backend/internal/config"
	"siagakita-backend/internal/database"
	adminDomain "siagakita-backend/internal/domain/admin"
	agencyDomain "siagakita-backend/internal/domain/agency"
	incidentDomain "siagakita-backend/internal/domain/incident"
	otpDomain "siagakita-backend/internal/domain/otp"
	"siagakita-backend/internal/domain/telemetry"
	userDomain "siagakita-backend/internal/domain/user"
	"siagakita-backend/internal/hub"
	"siagakita-backend/internal/middleware"
	"siagakita-backend/internal/ws"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

func main() {
	// ── 1. Load Config ────────────────────────────────────────────────────────
	cfg := config.Load()
	if cfg.JWTSecret == "" {
		log.Fatal("[Config] JWT_SECRET tidak boleh kosong")
	}

	// ── 2. Connect to PostgreSQL & Redis ─────────────────────────────────────
	db := database.NewPostgres(cfg)
	rdb := database.NewRedis(cfg)

	// ── 3. Superadmin seeding ─────────────────────────────────────────────────
	if err := seedSuperAdmin(db, cfg); err != nil {
		log.Fatalf("[SuperAdmin] Gagal seed superadmin: %v", err)
	}

	// ── 4. Connection Hub (WebSocket registry) ────────────────────────────────
	wsHub := hub.New()

	// ── 5. Domain wiring ──────────────────────────────────────────────────────
	// OTP domain
	fonnteGateway := otpDomain.NewFonnteGateway(cfg.FonnteToken)

	// Email gateway menggunakan Gmail REST API (OAuth2)
	log.Printf("[Email] Menggunakan Gmail REST API (from: %s)", cfg.EmailFrom)
	emailGateway := otpDomain.NewGmailAPIGateway(cfg.GmailClientID, cfg.GmailClientSecret, cfg.GmailRefreshToken, cfg.EmailFrom)

	otpSvc := otpDomain.NewService(rdb, fonnteGateway, emailGateway)
	otpHandler := otpDomain.NewHandler(otpSvc)

	// User domain
	userRepo := userDomain.NewRepository(db)
	userSvc := userDomain.NewService(userRepo, cfg, otpSvc)
	userHandler := userDomain.NewHandler(userSvc)

	// Incident domain
	incidentRepo := incidentDomain.NewRepository(db)
	incidentSvc := incidentDomain.NewService(incidentRepo, rdb)
	incidentHandler := incidentDomain.NewHandler(incidentSvc, cfg, wsHub, rdb)

	// Admin domain
	adminSvc := adminDomain.NewService(db)
	adminHandler := adminDomain.NewHandler(adminSvc, cfg)

	// Agency domain
	agencyRepo := agencyDomain.NewRepository(db)
	agencySvc := agencyDomain.NewService(agencyRepo)
	agencyHandler := agencyDomain.NewHandler(agencySvc)

	// Telemetry domain
	telemetryHandler := telemetry.NewHandler(rdb, wsHub, cfg)

	app := fiber.New(fiber.Config{
		AppName:   "SiagaKita API v1",
		BodyLimit: 15 * 1024 * 1024, // 15 MB
	})

	app.Use(recover.New())
	app.Use(logger.New(logger.Config{
		Format: "[${time}] ${status} ${method} ${path} (${latency})\n",
	}))
	app.Use(cors.New(cors.Config{
		AllowOrigins: "*",
		AllowHeaders: "Origin, Content-Type, Accept, Authorization, X-Gateway-Secret",
		AllowMethods: "GET, POST, PUT, PATCH, DELETE, OPTIONS",
	}))

	// Health check
	app.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{"status": "ok", "service": "SiagaKita REST API"})
	})

	// Static file serving for uploads
	uploadDir := cfg.UploadDir
	app.Get("/uploads/*", func(c *fiber.Ctx) error {
		subPath := c.Params("*")
		filePath := filepath.Join(uploadDir, filepath.Clean("/"+subPath))
		return c.SendFile(filePath)
	})

	// ── API v1 Routes ──────────────────────────────────────────────────────────
	v1 := app.Group("/api/v1")
	authMw := middleware.Auth(cfg)

	// ── Auth (public) ──────────────────────────────────────────────────────────
	auth := v1.Group("/auth")

	// Mobile Citizen/Volunteer
	auth.Post("/register", userHandler.Register)
	auth.Post("/verify-register-otp", userHandler.VerifyRegisterOTP)
	auth.Post("/login", userHandler.Login)
	auth.Post("/verify-login-otp", userHandler.VerifyLoginOTP)

	// Lupa password
	auth.Post("/forgot-password", userHandler.ForgotPassword)
	auth.Post("/reset-password", userHandler.ResetPassword)
	auth.Post("/resend-otp", userHandler.ResendOTP)

	// Desktop Console (superadmin, admin, agency)
	auth.Post("/console/login", userHandler.ConsoleLogin)

	// Mobile Responder (agency_personnel)
	auth.Post("/personnel/login", userHandler.PersonnelLogin)

	// OTP WhatsApp (phone verification)
	auth.Post("/request-otp", otpHandler.RequestOTP)
	auth.Post("/verify-otp", otpHandler.VerifyOTP)

	// ── Users (protected - civilian/volunteer only) ────────────────────────────
	users := v1.Group("/users", authMw, middleware.CitizenVolunteer(), middleware.TouchLastActive(db, rdb))
	users.Post("/biodata", userHandler.SaveBiodata)
	users.Get("/profile", userHandler.GetProfile)
	users.Put("/profile", userHandler.UpdateProfile)
	users.Post("/phone/request-otp", userHandler.RequestPhoneVerification)
	users.Post("/phone/verify-otp", userHandler.ConfirmPhoneOTP)
	// KYC: Verifikasi Identitas NIK Warga
	users.Post("/kyc", userHandler.SubmitKYC)
	users.Get("/kyc/status", userHandler.GetKYCStatus)
	// Pendaftaran Relawan
	users.Post("/volunteer/register", userHandler.SubmitVolunteerRegistration)
	// Ping: Heartbeat untuk update last_active_at (dipanggil tiap 30 detik dari mobile)
	users.Get("/ping", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{"status": "ok"})
	})

	// ── Incidents (protected - semua role yang sudah login) ───────────────────
	incidents := v1.Group("/incidents", authMw)
	incidents.Get("/active", incidentHandler.GetActive)
	incidents.Get("/my-history", middleware.VolunteerOnly(), incidentHandler.GetMissionHistory)
	incidents.Get("/reporter-history", incidentHandler.GetHistory)
	incidents.Get("/all-active", middleware.ConsoleOnly(), incidentHandler.GetAllActive)
	incidents.Get("/nearby", middleware.VolunteerOnly(), incidentHandler.GetNearby)
	incidents.Get("/agency/history", middleware.ConsoleOnly(), incidentHandler.GetAgencyHistory)
	incidents.Post("/:id/handle", middleware.AgencyOnly(), incidentHandler.AgencyHandleSOS)
	incidents.Post("/trigger", middleware.BanCheck(db), incidentHandler.TriggerSOS)
	incidents.Patch("/:id/type", incidentHandler.UpdateType)
	incidents.Post("/:id/broadcast", incidentHandler.Broadcast)
	incidents.Post("/:id/cancel", incidentHandler.CancelSOS)
	incidents.Post("/:id/evidence", incidentHandler.UploadEvidence)
	incidents.Put("/:id/location", incidentHandler.UpdateLocation)
	incidents.Post("/:id/accept", middleware.VolunteerOnly(), incidentHandler.AcceptSOS)
	incidents.Post("/:id/volunteer-complete", middleware.VolunteerOnly(), incidentHandler.VolunteerCompleteSOS)
	incidents.Post("/:id/agency-handle", middleware.ConsoleOnly(), incidentHandler.AgencyHandleSOS)
	incidents.Post("/:id/agency-review", middleware.ConsoleOnly(), incidentHandler.AgencyReviewVolunteer)
	incidents.Post("/:id/agency-resolve", middleware.ConsoleOnly(), incidentHandler.AgencyResolveSOS)
	incidents.Post("/:id/mark-false-alarm", middleware.ConsoleOnly(), incidentHandler.MarkFalseAlarm)
	// endpoint lama: incidents.Post("/:id/resolve", middleware.ConsoleOnly(), incidentHandler.Resolve) // bisa tetap ada atau diganti, kita pakai agency-resolve sekarang


	reports := v1.Group("/reports", authMw)
	reports.Post("", middleware.BanCheck(db), incidentHandler.CreateReport)
	reports.Get("/my", incidentHandler.GetMyReports)
	reports.Get("", middleware.ConsoleOnly(), incidentHandler.GetReports)
	reports.Post("/:id/cancel", incidentHandler.CancelReport)
	reports.Patch("/:id/status", middleware.ConsoleOnly(), incidentHandler.UpdateReportStatus)

	// ── Telemetry ─────────────────────────────────────────────────────────────
	telGroup := v1.Group("/telemetry", authMw)
	telGroup.Put("/location", telemetryHandler.UpdateLocation)
	telGroup.Post("/online-status", middleware.ConsoleOnly(), telemetryHandler.GetOnlineStatus)

	// ── Admin (protected - AdminOnly / ConsoleOnly) ───────────────────────────
	admin := v1.Group("/admin", authMw)

	// KYC Relawan
	admin.Get("/volunteers/pending", middleware.AdminOnly(), adminHandler.GetPendingKYC)
	admin.Post("/volunteers/:id/approve", middleware.AdminOnly(), adminHandler.ApproveKYC)
	admin.Post("/volunteers/:id/reject", middleware.AdminOnly(), adminHandler.RejectKYC)

	// Manajemen Pengguna
	admin.Post("/admins", middleware.SuperAdminOnly(), adminHandler.CreateAdmin)
	admin.Post("/agencies", middleware.AdminOnly(), adminHandler.CreateAgency)
	admin.Get("/users", middleware.AdminOnly(), adminHandler.GetUsers)
	admin.Get("/users/kyc/warga", middleware.AdminOnly(), adminHandler.GetPendingWargaKYC)
	admin.Post("/users/kyc/warga/:id/approve", middleware.AdminOnly(), adminHandler.ApproveWargaKYC)
	admin.Post("/users/kyc/warga/:id/reject", middleware.AdminOnly(), adminHandler.RejectWargaKYC)
	admin.Get("/users/:id/detail", middleware.AdminOnly(), adminHandler.GetUserDetail)
	admin.Post("/users/:id/ban", middleware.AdminOnly(), adminHandler.BanUser)
	admin.Post("/users/:id/unban", middleware.AdminOnly(), adminHandler.UnbanUser)
	admin.Delete("/users/:id/strike", middleware.AdminOnly(), adminHandler.ResetStrike)

	// Daftar Instansi & Admin
	admin.Get("/agencies", middleware.AdminOnly(), adminHandler.GetAgencies)
	admin.Get("/admins", middleware.SuperAdminOnly(), adminHandler.GetAdmins)

	// Master Data: Ranks
	admin.Get("/ranks", middleware.ConsoleOnly(), adminHandler.GetRanks)
	admin.Post("/ranks", middleware.AdminOnly(), adminHandler.CreateRank)
	admin.Put("/ranks/:id", middleware.AdminOnly(), adminHandler.UpdateRank)
	admin.Delete("/ranks/:id", middleware.AdminOnly(), adminHandler.DeleteRank)

	// Master Data: Badges
	admin.Get("/badges", middleware.ConsoleOnly(), adminHandler.GetBadges)
	admin.Post("/badges", middleware.AdminOnly(), adminHandler.CreateBadge)
	admin.Put("/badges/:id", middleware.AdminOnly(), adminHandler.UpdateBadge)
	admin.Delete("/badges/:id", middleware.AdminOnly(), adminHandler.DeleteBadge)

	// Statistik
	admin.Get("/stats", middleware.ConsoleOnly(), adminHandler.GetStats)

	// ── Agencies (protected - AgencyOnly) ─────────────────────────────────────
	agencies := v1.Group("/agencies", authMw)
	agencies.Get("/me", middleware.AgencyOnly(), agencyHandler.GetMyProfile)
	agencies.Post("/personnels", middleware.AgencyOnly(), agencyHandler.CreatePersonnel)

	// ── SMS Fallback (API key protected - no JWT) ─────────────────────────────
	v1.Post("/incidents/sms-fallback",
		middleware.APIKeyGateway(cfg),
		telemetryHandler.SMSFallback,
	)

	// ── 6. WebSocket Server (port :8081) ──────────────────────────────────────
	wsServer := ws.NewServer(wsHub, rdb, db, cfg)
	go func() {
		log.Printf("[WS] Starting WebSocket server on :%s", cfg.WSPort)
		if err := wsServer.ListenAndServe(); err != nil {
			log.Fatalf("[WS] Server error: %v", err)
		}
	}()

	// ── 7. Start Fiber REST API ───────────────────────────────────────────────
	go func() {
		log.Printf("[API] Starting REST API on :%s", cfg.HTTPPort)
		if err := app.Listen(":" + cfg.HTTPPort); err != nil {
			log.Fatalf("[API] Server error: %v", err)
		}
	}()

	// ── 8. Graceful shutdown ──────────────────────────────────────────────────
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, os.Interrupt, syscall.SIGTERM)
	<-quit

	log.Println("[Main] Shutting down gracefully...")
	if err := app.Shutdown(); err != nil {
		log.Printf("[API] Shutdown error: %v", err)
	}
	if err := wsServer.Shutdown(context.Background()); err != nil {
		log.Printf("[WS] Shutdown error: %v", err)
	}
	sqlDB, _ := db.DB()
	if err := sqlDB.Close(); err != nil {
		log.Printf("[DB] Close error: %v", err)
	}
	if err := rdb.Close(); err != nil {
		log.Printf("[Redis] Close error: %v", err)
	}
	log.Println("[Main] Goodbye.")
}

// seedSuperAdmin memastikan tepat satu akun superadmin ada di DB.
// Dipanggil sekali setiap server start. Jika env kosong, superadmin tidak dibuat/diupdate.
// Jika superadmin sudah ada tapi email/pass di env berubah, akun diperbarui.
func seedSuperAdmin(db *gorm.DB, cfg *config.Config) error {
	email := cfg.SuperAdminEmail
	pass := cfg.SuperAdminPass

	if email == "" || pass == "" {
		log.Println("[SuperAdmin] SUPERADMIN_EMAIL/PASS tidak diset di .env - skip seeding.")
		return nil
	}

	// Cari superadmin yang sudah ada
	var existing userDomain.User
	err := db.Where("role = 'superadmin' AND deleted_at IS NULL").First(&existing).Error

	if err == nil {
		// Superadmin sudah ada - update email/password jika berbeda
		hashed, err := bcrypt.GenerateFromPassword([]byte(pass), bcrypt.DefaultCost)
		if err != nil {
			return err
		}

		// Pastikan row admin_profiles ada dengan nama "root"
		type AdminProfile struct {
			UserID   string `gorm:"column:user_id;primaryKey"`
			FullName string `gorm:"column:full_name"`
		}
		var ap AdminProfile
		if err := db.Table("admin_profiles").Where("user_id = ?", existing.ID).First(&ap).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				db.Table("admin_profiles").Create(&AdminProfile{UserID: existing.ID, FullName: "root"})
			}
		}

		if existing.Email != email {
			log.Printf("[SuperAdmin] Memperbarui email superadmin menjadi: %s", email)
		}
		return db.Model(&existing).Updates(map[string]interface{}{
			"email":         email,
			"password_hash": string(hashed),
		}).Error
	}

	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return err
	}

	// Buat superadmin baru
	hashed, err := bcrypt.GenerateFromPassword([]byte(pass), bcrypt.DefaultCost)
	if err != nil {
		return err
	}

	err = db.Transaction(func(tx *gorm.DB) error {
		superadmin := userDomain.User{
			Email:        email,
			PasswordHash: string(hashed),
			Role:         "superadmin",
		}
		if err := tx.Create(&superadmin).Error; err != nil {
			return err
		}

		type AdminProfile struct {
			UserID   string `gorm:"column:user_id;primaryKey"`
			FullName string `gorm:"column:full_name"`
		}
		profile := AdminProfile{
			UserID:   superadmin.ID,
			FullName: "root",
		}
		return tx.Table("admin_profiles").Create(&profile).Error
	})
	if err != nil {
		return err
	}

	log.Printf("[SuperAdmin] Akun superadmin berhasil dibuat: %s", email)
	return nil
}
