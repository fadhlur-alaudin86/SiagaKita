// Purpose: WebSocket keepalive tests (F6): an idle client must not be reaped
// every ~90 s because the server now sends ping control frames on a
// per-connection ticker and the client's pong refreshes the read deadline.
// Data & Logic Flow: A minimal HTTP server upgrades a connection and runs the
// real readLoop with shortened wsPingInterval/wsReadDeadline. A gorilla client
// reads messages (so gorilla dispatches incoming pings to its default
// auto-pong handler) and sends nothing of its own. The test asserts the
// connection survives well past the shortened read deadline and that server
// pings are answered by client pongs.
// Key Components: TestReadLoop_KeepalivePingKeepsIdleConnectionAlive.

package ws

import (
	"net"
	"net/http"
	"sync/atomic"
	"testing"
	"time"

	"github.com/gorilla/websocket"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"siagakita-backend/internal/hub"
)

func TestReadLoop_KeepalivePingKeepsIdleConnectionAlive(t *testing.T) {
	// Save and restore the package-level timing vars so the test is hermetic.
	origPing := wsPingInterval()
	origDeadline := wsReadDeadline()
	defer func() {
		wsPingIntervalNs.Store(int64(origPing))
		wsReadDeadlineNs.Store(int64(origDeadline))
	}()

	// Shorten both the ping interval and the read deadline so the test runs
	// quickly: ping every 100 ms, deadline 400 ms. A ping well before the
	// deadline, answered by a pong, keeps refreshing the deadline.
	wsPingIntervalNs.Store(int64(100 * time.Millisecond))
	wsReadDeadlineNs.Store(int64(400 * time.Millisecond))

	upgrader := websocket.Upgrader{
		ReadBufferSize:  1024,
		WriteBufferSize: 1024,
		CheckOrigin:     func(r *http.Request) bool { return true },
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			return
		}
		h := &Handler{hub: hub.New()}
		go h.readLoop("test-user", conn)
	})

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	require.NoError(t, err)
	srv := &http.Server{Handler: mux}
	go srv.Serve(ln)
	t.Cleanup(func() { _ = srv.Close() })

	clientConn, _, err := websocket.DefaultDialer.Dial("ws://"+ln.Addr().String()+"/ws", nil)
	require.NoError(t, err)
	defer clientConn.Close()

	// Count keepalive pings received by the client and answer each with a pong
	// so the server's read deadline keeps refreshing. gorilla's default ping
	// handler would do this automatically, but we count explicitly for the
	// assertion.
	var clientPings int32
	clientConn.SetPingHandler(func(appData string) error {
		atomic.AddInt32(&clientPings, 1)
		return clientConn.WriteControl(websocket.PongMessage, nil, time.Now().Add(5*time.Second))
	})

	// Client reads messages so gorilla dispatches incoming frames. A real WS
	// client is always reading.
	go func() {
		for {
			if _, _, err := clientConn.ReadMessage(); err != nil {
				return
			}
		}
	}()

	// Send nothing of our own: idle. Wait well past the shortened (400 ms)
	// read deadline.
	time.Sleep(2 * time.Second)

	// The connection must still be open: a write must succeed. If the server
	// had reaped the idle client (old behavior), the write would fail.
	require.NoError(t, clientConn.SetWriteDeadline(time.Now().Add(500*time.Millisecond)))
	require.NoError(t, clientConn.WriteMessage(websocket.PingMessage, nil),
		"idle client was reaped before the deadline — keepalive not working")

	// Server keepalive pings should have reached the client. Over a 2 s window
	// at a 100 ms ping interval ~20 pings are expected; a floor of 10 keeps a
	// ~50 % margin against scheduler/jitter delay while still proving the
	// readLoop survived well past the (shortened) 400 ms read deadline via
	// pong-refreshed deadlines — i.e. the keepalive mechanism, not a stray
	// successful write, is what kept the connection open.
	assert.GreaterOrEqual(t, atomic.LoadInt32(&clientPings), int32(10),
		"server should have sent keepalive pings answered by client pongs")
}
