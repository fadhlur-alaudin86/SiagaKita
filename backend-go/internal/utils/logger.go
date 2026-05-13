package utils

import (
	"io"
	"os"
	"path/filepath"
	"time"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
)

// Logger adalah instance global untuk logging
var Logger zerolog.Logger

// InitLogger menginisialisasi zerolog dengan konfigurasi tertentu
func InitLogger(isProd bool) {
	zerolog.TimeFieldFormat = time.RFC3339

	var writers []io.Writer
	writers = append(writers, os.Stdout)

	// Simpan ke file jika di produksi atau jika LOG_PATH diset
	logPath := os.Getenv("LOG_PATH")
	if logPath == "" && isProd {
		logPath = "logs/app.log"
	}

	if logPath != "" {
		// Pastikan folder log ada
		_ = os.MkdirAll(filepath.Dir(logPath), 0755)
		file, err := os.OpenFile(logPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
		if err == nil {
			writers = append(writers, file)
		}
	}

	mw := io.MultiWriter(writers...)

	if !isProd {
		// Output cantik di console untuk development (wrapper di atas multi-writer)
		log.Logger = log.Output(zerolog.ConsoleWriter{
			Out:        mw,
			TimeFormat: "15:04:05",
		})
	} else {
		log.Logger = zerolog.New(mw).With().Timestamp().Logger()
	}

	Logger = log.Logger
}

// Log level helpers
func Info() *zerolog.Event {
	return Logger.Info()
}

func Error() *zerolog.Event {
	return Logger.Error()
}

func Debug() *zerolog.Event {
	return Logger.Debug()
}

func Warn() *zerolog.Event {
	return Logger.Warn()
}

func Fatal() *zerolog.Event {
	return Logger.Fatal()
}
