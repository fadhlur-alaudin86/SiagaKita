package hub

import (
	"encoding/json"
	"log"
	"sync"

	"github.com/gorilla/websocket"
)

// Message is the standard WebSocket message envelope.
type Message struct {
	Event   string      `json:"event"`
	Payload interface{} `json:"payload"`
}

// Hub maintains the map of active WebSocket connections keyed by userID.
// All public methods are safe for concurrent use.
type Hub struct {
	mu      sync.RWMutex
	clients map[string]*websocket.Conn
}

// New creates a new Hub instance.
func New() *Hub {
	return &Hub{
		clients: make(map[string]*websocket.Conn),
	}
}

// Register adds or replaces a connection for the given userID.
func (h *Hub) Register(userID string, conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()

	// Close existing connection if already present
	if existing, ok := h.clients[userID]; ok {
		_ = existing.Close()
	}
	h.clients[userID] = conn
	log.Printf("[Hub] User %s connected (total=%d)", userID, len(h.clients))
}

// Unregister closes and removes the connection for the given userID.
func (h *Hub) Unregister(userID string) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if conn, ok := h.clients[userID]; ok {
		_ = conn.Close()
		delete(h.clients, userID)
		log.Printf("[Hub] User %s disconnected (total=%d)", userID, len(h.clients))
	}
}

// SendToUser sends a Message to a specific user. Returns nil if user is offline.
func (h *Hub) SendToUser(userID string, msg Message) error {
	h.mu.RLock()
	conn, ok := h.clients[userID]
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
	return conn.WriteMessage(websocket.TextMessage, data)
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
