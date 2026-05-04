package database

import (
	"context"
	"fmt"
	"log"
	"strings"

	"siagakita-backend/internal/config"

	"github.com/redis/go-redis/v9"
)

// NewRedis creates and returns a connected go-redis client.
func NewRedis(cfg *config.Config) *redis.Client {
	rdb := redis.NewClient(&redis.Options{
		Addr:     fmt.Sprintf("%s:%s", cfg.RedisHost, cfg.RedisPort),
		Password: cfg.RedisPassword,
		DB:       0,
	})

	if err := rdb.Ping(context.Background()).Err(); err != nil {
		log.Fatalf("[Redis] Failed to connect: %v", err)
	}

	log.Println("[Redis] Connected successfully")
	return rdb
}

// SubscribeExpiredKeys subscribes to Redis keyspace notifications for expired keys.
// Calls handler(key) whenever a key with the given prefix expires.
// This requires Redis to be started with --notify-keyspace-events Ex.
func SubscribeExpiredKeys(ctx context.Context, rdb *redis.Client, prefix string, handler func(key string)) {
	pubsub := rdb.PSubscribe(ctx, "__keyevent@0__:expired")
	ch := pubsub.Channel()

	go func() {
		defer func() { _ = pubsub.Close() }()
		log.Printf("[Redis] Subscribed to expired key events (prefix=%q)", prefix)
		for {
			select {
			case <-ctx.Done():
				return
			case msg, ok := <-ch:
				if !ok {
					return
				}
				if strings.HasPrefix(msg.Payload, prefix) {
					handler(msg.Payload)
				}
			}
		}
	}()
}
