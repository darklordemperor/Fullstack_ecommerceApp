package db

import (
	"context"
	"time"

	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

type Mongo struct {
	Client   *mongo.Client
	Database *mongo.Database
}

// Connect opens a pooled MongoDB connection. Schema setup (indexes, backfills)
// is handled separately by RunMigrations so it is versioned and tracked.
//
// A bounded connection pool lets many concurrent requests share a small set of
// sockets instead of opening one per request (which would exhaust the database
// under load) — the pool is what makes the API scale horizontally: add more
// API nodes behind a load balancer and each keeps its own capped pool. The
// server-selection timeout ensures a request fails fast with an error rather
// than blocking indefinitely when no healthy node is reachable.
func Connect(uri, database string, maxPool, minPool uint64) (*Mongo, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	opts := options.Client().
		ApplyURI(uri).
		SetMaxPoolSize(maxPool).
		SetMinPoolSize(minPool).
		SetServerSelectionTimeout(5 * time.Second).
		SetRetryWrites(true)

	client, err := mongo.Connect(opts)
	if err != nil {
		return nil, err
	}
	if err := client.Ping(ctx, nil); err != nil {
		return nil, err
	}

	return &Mongo{Client: client, Database: client.Database(database)}, nil
}
