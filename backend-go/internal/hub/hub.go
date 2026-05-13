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

type Client struct {
	Conn *websocket.Conn
	Role string
}

// Hub maintains the map of active WebSocket connections keyed by userID.
// All public methods are safe for concurrent use.
type Hub struct {
	mu      sync.RWMutex
	clients map[string]*Client
}

// New creates a new Hub instance.
func New() *Hub {
	return &Hub{
		clients: make(map[string]*Client),
	}
}

// Register adds or replaces a connection for the given userID and role.
func (h *Hub) Register(userID, role string, conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()

	// Close existing connection if already present
	if existing, ok := h.clients[userID]; ok {
		_ = existing.Conn.Close()
	}
	h.clients[userID] = &Client{Conn: conn, Role: role}
	utils.Info().Str("user_id", userID).Str("role", role).Int("total_clients", len(h.clients)).Msg("[Hub] User connected")
}

// Unregister closes and removes the connection for the given userID.
func (h *Hub) Unregister(userID string) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if client, ok := h.clients[userID]; ok {
		_ = client.Conn.Close()
		delete(h.clients, userID)
		utils.Info().Str("user_id", userID).Int("total_clients", len(h.clients)).Msg("[Hub] User disconnected")
	}
}

// SendToUser sends a Message to a specific user. Returns nil if user is offline.
func (h *Hub) SendToUser(userID string, msg Message) error {
	h.mu.RLock()
	client, ok := h.clients[userID]
	h.mu.RUnlock()

	if !ok {
		return nil // user offline — silently skip
	}

	data, err := json.Marshal(msg)
	if err != nil {
		return err
	}

	h.mu.Lock()
	defer h.mu.Unlock()
	return client.Conn.WriteMessage(websocket.TextMessage, data)
}

// IsOnline reports whether the given userID has an active connection.
func (h *Hub) IsOnline(userID string) bool {
	h.mu.RLock()
	defer h.mu.RUnlock()
	_, ok := h.clients[userID]
	return ok
}

// OnlineUsers returns a snapshot of all currently connected user IDs.
func (h *Hub) OnlineUsers() []string {
	h.mu.RLock()
	defer h.mu.RUnlock()

	ids := make([]string, 0, len(h.clients))
	for id := range h.clients {
		ids = append(ids, id)
	}
	return ids
}

// BroadcastToRole sends a Message to all connected clients that have the specified role.
// Returns the number of successful sends.
func (h *Hub) BroadcastToRole(role string, msg Message) int {
	data, err := json.Marshal(msg)
	if err != nil {
		return 0
	}

	h.mu.RLock()
	var targets []*websocket.Conn
	for _, client := range h.clients {
		if client.Role == role {
			targets = append(targets, client.Conn)
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
