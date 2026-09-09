package hub

import (
	"encoding/json"
	"siagakita-backend/internal/utils"
	"sync"

	"github.com/gorilla/websocket"
)

// Message is the standard WebSocket message envelope.
type Message struct {
	Event   string      `json:"event"`
	Payload interface{} `json:"payload"`
}

// consoleRoles adalah role yang boleh punya lebih dari 1 koneksi WS aktif.
var consoleRoles = map[string]bool{
	"agency":     true,
	"admin":      true,
	"superadmin": true,
}

type Client struct {
	Conn   *websocket.Conn
	Role   string
	ConnID string // UUID unik per koneksi (untuk Unregister tepat sasaran)
}

// Hub maintains the map of active WebSocket connections.
//
//   - Mobile roles (civilian, volunteer): 1 koneksi per userID (lama di-replace)
//   - Console roles (agency, admin, superadmin): multiple koneksi per userID
//
// All public methods are safe for concurrent use.
type Hub struct {
	mu      sync.RWMutex
	clients map[string][]*Client // userID → slice of Clients
}

// New creates a new Hub instance.
func New() *Hub {
	return &Hub{
		clients: make(map[string][]*Client),
	}
}

// Register adds a connection for the given userID and role.
// For mobile roles: replaces any existing connection (single-session).
// For console roles: appends to the existing list (multi-session).
func (h *Hub) Register(userID, role, connID string, conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()

	newClient := &Client{Conn: conn, Role: role, ConnID: connID}

	if consoleRoles[role] {
		// Console: tambah ke slice (multi-device)
		h.clients[userID] = append(h.clients[userID], newClient)
	} else {
		// Mobile: tutup koneksi lama, replace dengan yang baru
		for _, existing := range h.clients[userID] {
			_ = existing.Conn.Close()
		}
		h.clients[userID] = []*Client{newClient}
	}

	utils.Info().
		Str("user_id", userID).
		Str("role", role).
		Str("conn_id", connID).
		Int("total_clients", len(h.clients)).
		Msg("[Hub] User connected")
}

// Unregister removes the specific connection (by connID) for the given userID.
func (h *Hub) Unregister(userID, connID string) {
	h.mu.Lock()
	defer h.mu.Unlock()

	existing := h.clients[userID]
	updated := existing[:0]
	for _, c := range existing {
		if c.ConnID == connID {
			_ = c.Conn.Close()
		} else {
			updated = append(updated, c)
		}
	}

	if len(updated) == 0 {
		delete(h.clients, userID)
		utils.Info().Str("user_id", userID).Str("conn_id", connID).Int("total_clients", len(h.clients)).Msg("[Hub] User disconnected (all conns gone)")
	} else {
		h.clients[userID] = updated
		utils.Info().Str("user_id", userID).Str("conn_id", connID).Int("remaining_conns", len(updated)).Msg("[Hub] User connection removed (other conns remain)")
	}
}

// SendToUser sends a Message to ALL connections of a specific user.
// Returns nil if user is offline. Silently skips failed sends.
func (h *Hub) SendToUser(userID string, msg Message) error {
	data, err := json.Marshal(msg)
	if err != nil {
		return err
	}

	h.mu.Lock()
	defer h.mu.Unlock()

	clients, ok := h.clients[userID]
	if !ok || len(clients) == 0 {
		return nil // user offline
	}

	for _, c := range clients {
		_ = c.Conn.WriteMessage(websocket.TextMessage, data)
	}
	return nil
}

// IsOnline reports whether the given userID has at least one active connection.
func (h *Hub) IsOnline(userID string) bool {
	h.mu.RLock()
	defer h.mu.RUnlock()
	conns, ok := h.clients[userID]
	return ok && len(conns) > 0
}

// OnlineUsers returns a snapshot of all currently connected user IDs.
func (h *Hub) OnlineUsers() []string {
	h.mu.RLock()
	defer h.mu.RUnlock()

	ids := make([]string, 0, len(h.clients))
	for id, conns := range h.clients {
		if len(conns) > 0 {
			ids = append(ids, id)
		}
	}
	return ids
}

// BroadcastToRole sends a Message to all connected clients with the specified role.
// Returns the number of successful sends.
func (h *Hub) BroadcastToRole(role string, msg Message) int {
	data, err := json.Marshal(msg)
	if err != nil {
		return 0
	}

	h.mu.RLock()
	var targets []*websocket.Conn
	for _, conns := range h.clients {
		for _, c := range conns {
			if c.Role == role {
				targets = append(targets, c.Conn)
			}
		}
	}
	h.mu.RUnlock()

	sent := 0
	h.mu.Lock()
	defer h.mu.Unlock()
	for _, conn := range targets {
		if err := conn.WriteMessage(websocket.TextMessage, data); err == nil {
			sent++
		}
	}
	return sent
}

// BroadcastToRoles sends a Message to all connected clients matching any of the specified roles,
// optionally excluding a specific user ID (e.g. the incident reporter).
// Returns the number of successful sends without database or Redis round-trips.
func (h *Hub) BroadcastToRoles(msg Message, excludeUserID string, roles ...string) int {
	data, err := json.Marshal(msg)
	if err != nil {
		return 0
	}

	roleMap := make(map[string]bool, len(roles))
	for _, r := range roles {
		roleMap[r] = true
	}

	h.mu.RLock()
	var targets []*websocket.Conn
	for userID, conns := range h.clients {
		if excludeUserID != "" && userID == excludeUserID {
			continue
		}
		for _, c := range conns {
			if roleMap[c.Role] {
				targets = append(targets, c.Conn)
			}
		}
	}
	h.mu.RUnlock()

	sent := 0
	h.mu.Lock()
	defer h.mu.Unlock()
	for _, conn := range targets {
		if err := conn.WriteMessage(websocket.TextMessage, data); err == nil {
			sent++
		}
	}
	return sent
}
