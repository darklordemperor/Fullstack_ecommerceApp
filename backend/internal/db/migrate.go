package db

import (
	"context"
	"fmt"
	"log/slog"
	"sort"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

// Migration is a single ordered, idempotent schema change. For MongoDB
// (schemaless) these are chiefly index definitions and data backfills. Every
// applied version is recorded in the schema_migrations collection so a
// migration runs exactly once across all nodes and deploys — the replacement
// for "just create indexes on every boot", which cannot express data changes or
// track what has run.
type Migration struct {
	Version int
	Name    string
	Up      func(ctx context.Context, db *mongo.Database) error
}

// migrations is the ordered ledger. Append new versions; never edit or reorder
// a migration that has already shipped.
var migrations = []Migration{
	{Version: 1, Name: "create_core_indexes", Up: createCoreIndexes},
}

type migrationRecord struct {
	Version   int       `bson:"_id"`
	Name      string    `bson:"name"`
	AppliedAt time.Time `bson:"applied_at"`
}

// RunMigrations applies every migration not yet recorded, in version order,
// recording each as it succeeds.
func RunMigrations(ctx context.Context, db *mongo.Database) error {
	coll := db.Collection("schema_migrations")
	applied, err := appliedVersions(ctx, coll)
	if err != nil {
		return err
	}
	for _, m := range pendingMigrations(applied, migrations) {
		if err := m.Up(ctx, db); err != nil {
			return fmt.Errorf("migration %d (%s): %w", m.Version, m.Name, err)
		}
		if _, err := coll.InsertOne(ctx, migrationRecord{
			Version:   m.Version,
			Name:      m.Name,
			AppliedAt: time.Now(),
		}); err != nil {
			return err
		}
		slog.Info("applied migration", "version", m.Version, "name", m.Name)
	}
	return nil
}

func appliedVersions(ctx context.Context, coll *mongo.Collection) (map[int]bool, error) {
	cursor, err := coll.Find(ctx, bson.M{})
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)
	var records []migrationRecord
	if err := cursor.All(ctx, &records); err != nil {
		return nil, err
	}
	applied := make(map[int]bool, len(records))
	for _, r := range records {
		applied[r.Version] = true
	}
	return applied, nil
}

// pendingMigrations returns the not-yet-applied migrations, sorted by version.
// Kept pure (no DB) so it is unit-testable.
func pendingMigrations(applied map[int]bool, all []Migration) []Migration {
	pending := make([]Migration, 0, len(all))
	for _, m := range all {
		if !applied[m.Version] {
			pending = append(pending, m)
		}
	}
	sort.Slice(pending, func(i, j int) bool { return pending[i].Version < pending[j].Version })
	return pending
}

// createCoreIndexes (migration v1) creates the indexes that back the app's read
// patterns. Every query that filters or sorts should be able to use an index;
// without these the queries fall back to full collection scans that degrade as
// data grows.
func createCoreIndexes(ctx context.Context, db *mongo.Database) error {
	specs := []struct {
		collection string
		model      mongo.IndexModel
	}{
		// Unique login key; also enforces one account per email.
		{"users", mongo.IndexModel{
			Keys:    bson.D{{Key: "email", Value: 1}},
			Options: options.Index().SetUnique(true),
		}},
		// Seller dashboard: list a seller's products.
		{"products", mongo.IndexModel{Keys: bson.D{{Key: "seller_id", Value: 1}}}},
		// Storefront default sort (newest first) with no category filter.
		{"products", mongo.IndexModel{Keys: bson.D{{Key: "created_at", Value: -1}}}},
		// Storefront filtered by category and sorted by newest.
		{"products", mongo.IndexModel{Keys: bson.D{
			{Key: "category", Value: 1},
			{Key: "created_at", Value: -1},
		}}},
		// One cart per user; the cart lookup and upsert both key on user_id.
		{"carts", mongo.IndexModel{
			Keys:    bson.D{{Key: "user_id", Value: 1}},
			Options: options.Index().SetUnique(true),
		}},
		// Seller order history, newest first.
		{"orders", mongo.IndexModel{Keys: bson.D{
			{Key: "seller_id", Value: 1},
			{Key: "created_at", Value: -1},
		}}},
		// Customer order history, newest first.
		{"orders", mongo.IndexModel{Keys: bson.D{
			{Key: "customer_id", Value: 1},
			{Key: "created_at", Value: -1},
		}}},
		// Refresh token lookup is by hash; the hash is unique.
		{"refresh_tokens", mongo.IndexModel{
			Keys:    bson.D{{Key: "token_hash", Value: 1}},
			Options: options.Index().SetUnique(true),
		}},
		// Revoke-all-for-user (reuse detection / logout everywhere) filters by user.
		{"refresh_tokens", mongo.IndexModel{Keys: bson.D{{Key: "user_id", Value: 1}}}},
		// TTL index: MongoDB auto-deletes tokens once expires_at passes.
		{"refresh_tokens", mongo.IndexModel{
			Keys:    bson.D{{Key: "expires_at", Value: 1}},
			Options: options.Index().SetExpireAfterSeconds(0),
		}},
	}

	for _, spec := range specs {
		if _, err := db.Collection(spec.collection).Indexes().CreateOne(ctx, spec.model); err != nil {
			return err
		}
	}
	return nil
}
