package i18n

import (
	"fmt"
	"strings"

	"github.com/gofiber/fiber/v2"
)

// Supported language codes
const (
	LocaleID = "id"
	LocaleEN = "en"
)

// idToEn holds static message translations from Indonesian to English.
var idToEn = map[string]string{
	// ── Auth & Session ──────────────────────────────────────────────────────────
	"Authorization header missing atau tidak valid":              "Missing or invalid Authorization header",
	"Token tidak valid atau sudah kedaluwarsa":                   "Invalid or expired token",
	"Token tidak valid":                                          "Invalid token",
	"Gateway secret tidak valid":                                 "Invalid gateway secret",
	"Akses ditolak: izin tidak mencukupi":                        "Access denied: insufficient permissions",
	"Akun Anda saat ini diblokir dari fitur SOS. Hubungi admin.": "Your account is currently banned from the SOS feature. Contact admin.",
	"Sesi Anda telah berakhir karena login di perangkat lain.":   "Your session has ended because you logged in on another device.",
	"Permintaan duplikat sedang diproses, coba lagi nanti":       "Duplicate request is being processed, please try again later",
	"unauthorized": "Unauthorized access",

	// ── User & Auth Operations ──────────────────────────────────────────────────
	"Body request tidak valid":                         "Invalid request body",
	"Format JSON tidak valid":                          "Invalid JSON format",
	"email dan otp_code wajib diisi":                   "Email and OTP code are required",
	"phone_number dan otp_code wajib diisi":            "Phone number and OTP code are required",
	"phone_number wajib diisi":                         "Phone number is required",
	"Email wajib diisi":                                "Email is required",
	"Email, OTP, dan Password baru wajib diisi":        "Email, OTP, and new password are required",
	"Email dan context wajib diisi":                    "Email and context are required",
	"nik dan full_name wajib diisi":                    "NIK and full name are required",
	"NIK harus 16 digit":                               "NIK must be 16 digits",
	"Nama lengkap maksimal 100 karakter":               "Full name maximum 100 characters",
	"Tempat lahir maksimal 100 karakter":               "Place of birth maximum 100 characters",
	"Profil tidak ditemukan":                           "Profile not found",
	"Data profil tidak ditemukan":                      "Profile data not found",
	"Gagal memuat profil terbaru":                      "Failed to load latest profile",
	"Email sudah terdaftar":                            "Email is already registered",
	"Nomor telepon sudah terdaftar":                    "Phone number is already registered",
	"NIK sudah terdaftar":                              "NIK is already registered",
	"Email atau kata sandi salah":                      "Invalid email or password",
	"Email atau password salah.":                       "Invalid email or password.",
	"Kode OTP salah atau sudah kedaluwarsa":            "Invalid or expired OTP code",
	"Registrasi berhasil":                              "Registration successful",
	"Password berhasil diubah. Silakan login kembali.": "Password changed successfully. Please log in again.",
	"Kode OTP baru telah dikirim":                      "A new OTP code has been sent",
	"Nomor WhatsApp berhasil diverifikasi":             "WhatsApp number successfully verified",
	"Verifikasi NIK berhasil diajukan":                 "NIK verification successfully submitted",
	"Profil berhasil diperbarui":                       "Profile successfully updated",
	"User tidak ditemukan":                             "User not found",

	// ── Incidents & SOS ─────────────────────────────────────────────────────────
	"Koordinat GPS wajib diisi":                          "GPS coordinates are required",
	"Alasan (reason) wajib diisi":                        "Reason is required",
	"Status wajib diisi":                                 "Status is required",
	"incident_type wajib diisi":                          "Incident type is required",
	"Form tidak valid":                                   "Invalid form",
	"Parameter 'lat' wajib diisi dan harus berupa angka": "Parameter 'lat' is required and must be a number",
	"Parameter 'lng' wajib diisi dan harus berupa angka": "Parameter 'lng' is required and must be a number",
	"SOS sudah aktif.":                                   "SOS is already active.",
	"SOS diterima. Pilih jenis darurat atau tunggu 10 detik untuk dikirim otomatis.": "SOS received. Select emergency type or wait 10 seconds for automatic dispatch.",
	"Tipe insiden diperbarui, SOS sedang disiarkan.":                                 "Incident type updated, SOS is broadcasting.",
	"SOS sedang disiarkan ke relawan dan instansi terdekat.":                         "SOS is broadcasting to nearby volunteers and agencies.",
	"Panggilan SOS berhasil dibatalkan.":                                             "SOS call successfully canceled.",
	"sos_banned: akun Anda dinonaktifkan dari fitur SOS karena pelanggaran berulang": "sos_banned: your account is banned from the SOS feature due to repeated violations",
	"Akun Anda dinonaktifkan dari fitur SOS karena pelanggaran berulang":             "Your account is banned from the SOS feature due to repeated violations",
	"tipe hanya bisa diubah saat grace period":                                       "Incident type can only be changed during the grace period",
	"tipe insiden wajib diisi dan tidak boleh 'unknown' untuk laporan warga":         "Incident type is required and cannot be 'unknown' for citizen reports",
	"lokasi harus diisi (latitude dan longitude tidak boleh 0)":                      "Location is required (latitude and longitude cannot be 0)",
	"Insiden tidak ditemukan":                                                        "Incident not found",
	"Laporan tidak ditemukan":                                                        "Report not found",
	"Relawan tidak ditemukan":                                                        "Volunteer not found",
	"Misi berhasil diterima. Segera menuju lokasi.":                                  "Mission accepted successfully. Proceed to the location immediately.",
	"Misi telah selesai. Bukti telah diverifikasi.":                                  "Mission completed. Evidence has been verified.",
	"Laporan berhasil dibuat":                                                        "Report created successfully",
	"Laporan berhasil dibatalkan":                                                    "Report canceled successfully",
	"Status laporan berhasil diperbarui":                                             "Report status updated successfully",
	"Insiden telah dibatalkan atau sudah selesai":                                    "Incident has been canceled or already resolved",
	"Insiden sedang ditangani oleh responder lain":                                   "Incident is currently being handled by another responder",
	"Parameter lat dan lng wajib diisi":                                              "lat and lng parameters are required",
	"Parameter lat tidak valid":                                                      "Invalid lat parameter",
	"Parameter lng tidak valid":                                                      "Invalid lng parameter",
	"Gagal mengambil data relawan terdekat":                                          "Failed to get nearby volunteers",
	"Daftar volunteer_ids wajib diisi":                                               "volunteer_ids list is required",
	"Broadcast penugasan berhasil dikirim":                                           "Dispatch broadcast sent successfully",
	"Gagal mengirim broadcast penugasan":                                             "Failed to send dispatch broadcast",
	"Insiden sudah ditangani atau selesai":                                           "Incident already handled or completed",

	// ── Admin & Agency ──────────────────────────────────────────────────────────
	"Admin tidak ditemukan":      "Admin not found",
	"Instansi tidak ditemukan":   "Agency not found",
	"Gagal memuat data":          "Failed to load data",
	"Data berhasil disimpan":     "Data saved successfully",
	"Data berhasil diperbarui":   "Data updated successfully",
	"Data berhasil dihapus":      "Data deleted successfully",
	"Internal server error":      "Internal server error",
	"Data tidak ditemukan":       "Data not found",
	"Terjadi kesalahan internal": "An internal error occurred",
}

// GetLocale detects the client's preferred language.
// Priority:
// 1. Fiber context local "locale" (if set by middleware)
// 2. Query param ?lang= (useful for WebSockets or testing)
// 3. Header Accept-Language (RFC 9110 standard)
// Default fallback is LocaleID ("id").
func GetLocale(c *fiber.Ctx) string {
	if c == nil {
		return LocaleID
	}

	if loc, ok := c.Locals("locale").(string); ok && loc != "" {
		return normalizeLocale(loc)
	}

	if q := c.Query("lang"); q != "" {
		return normalizeLocale(q)
	}

	acceptLang := c.Get("Accept-Language")
	if acceptLang != "" {
		return parseAcceptLanguage(acceptLang)
	}

	return LocaleID
}

// normalizeLocale normalizes common locale codes to "id" or "en".
func normalizeLocale(code string) string {
	code = strings.ToLower(strings.TrimSpace(code))
	if strings.HasPrefix(code, "en") {
		return LocaleEN
	}
	return LocaleID
}

// parseAcceptLanguage parses an Accept-Language header value and determines
// whether English or Indonesian is preferred.
func parseAcceptLanguage(header string) string {
	parts := strings.Split(header, ",")
	for _, part := range parts {
		tag := strings.TrimSpace(strings.Split(part, ";")[0])
		if strings.HasPrefix(strings.ToLower(tag), "en") {
			return LocaleEN
		}
		if strings.HasPrefix(strings.ToLower(tag), "id") {
			return LocaleID
		}
	}
	return LocaleID
}

// Translate translates a message into the target language.
// If lang is not "en", it returns the original message.
// Dynamic formats like "Insiden ditandai false alarm. Pelanggaran %d/3." are handled.
func Translate(lang string, message string, args ...interface{}) string {
	if len(args) > 0 {
		message = fmt.Sprintf(message, args...)
	}

	if lang != LocaleEN {
		return message
	}

	// 1. Direct dictionary match
	if translated, ok := idToEn[message]; ok {
		return translated
	}

	// 2. Dynamic pattern matching
	var strikeCount int
	if n, _ := fmt.Sscanf(message, "Insiden ditandai false alarm. Pelanggaran %d/3.", &strikeCount); n == 1 {
		return fmt.Sprintf("Incident marked as false alarm. Violation %d/3.", strikeCount)
	}
	if message == "Insiden ditandai false alarm. Akun pelapor telah diblokir dari fitur SOS (3 pelanggaran)." {
		return "Incident marked as false alarm. Reporter account has been banned from the SOS feature (3 violations)."
	}

	const invalidTypePrefix = "tipe insiden tidak valid: "
	if strings.HasPrefix(message, invalidTypePrefix) {
		val := strings.TrimPrefix(message, invalidTypePrefix)
		return fmt.Sprintf("Invalid incident type: %s", val)
	}

	const otpErrorPrefix = "Gagal mengirim OTP: "
	if strings.HasPrefix(message, otpErrorPrefix) {
		val := strings.TrimPrefix(message, otpErrorPrefix)
		return fmt.Sprintf("Failed to send OTP: %s", val)
	}

	// Fallback to original message if no translation found
	return message
}

// T is a convenience helper for translating within a Fiber request context.
func T(c *fiber.Ctx, message string, args ...interface{}) string {
	return Translate(GetLocale(c), message, args...)
}
