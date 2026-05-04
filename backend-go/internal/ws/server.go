package ws

import (
	"fmt"
	"log"
	"net/http"

	"siagakita-backend/internal/config"
	"siagakita-backend/internal/hub"

	"github.com/redis/go-redis/v9"
	"gorm.io/gorm"
)

// NewServer creates a net/http server for WebSocket connections on the configured WS port.
// It runs alongside the Fiber REST API on a separate port.
func NewServer(h *hub.Hub, rdb *redis.Client, db *gorm.DB, cfg *config.Config) *http.Server {
	wsHandler := NewHandler(h, rdb, db, cfg)

	mux := http.NewServeMux()
	mux.HandleFunc("/v1/ws/connect", wsHandler.ServeWS)

	// Health check for WS server
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		_, _ = fmt.Fprintln(w, "WS OK")
	})

	addr := fmt.Sprintf(":%s", cfg.WSPort)
	log.Printf("[WS] Server listening on %s", addr)

	return &http.Server{
		Addr:    addr,
		Handler: mux,
	}
}
