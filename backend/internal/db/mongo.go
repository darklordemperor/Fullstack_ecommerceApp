package db

import (
	"context"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

type Mongo struct {
	Client   *mongo.Client
	Database *mongo.Database
}

func Connect(uri, database string) (*Mongo, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	client, err := mongo.Connect(options.Client().ApplyURI(uri))
	if err != nil {
		return nil, err
	}
	if err := client.Ping(ctx, nil); err != nil {
		return nil, err
	}

	m := &Mongo{Client: client, Database: client.Database(database)}
	return m, m.ensureIndexes(ctx)
}

func (m *Mongo) ensureIndexes(ctx context.Context) error {
	_, err := m.Database.Collection("users").Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys:    bson.D{{Key: "email", Value: 1}},
		Options: options.Index().SetUnique(true),
	})
	if err != nil {
		return err
	}
	_, err = m.Database.Collection("products").Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys: bson.D{{Key: "seller_id", Value: 1}},
	})
	if err != nil {
		return err
	}
	if _, err = m.Database.Collection("conversations").Indexes().CreateMany(ctx, []mongo.IndexModel{
		{Keys: bson.D{{Key: "buyer_id", Value: 1}, {Key: "updated_at", Value: -1}}},
		{Keys: bson.D{{Key: "seller_id", Value: 1}, {Key: "updated_at", Value: -1}}},
		{
			Keys:    bson.D{{Key: "buyer_id", Value: 1}, {Key: "seller_id", Value: 1}, {Key: "product_id", Value: 1}},
			Options: options.Index().SetUnique(true),
		},
	}); err != nil {
		return err
	}
	_, err = m.Database.Collection("chat_messages").Indexes().CreateMany(ctx, []mongo.IndexModel{
		{Keys: bson.D{{Key: "conversation_id", Value: 1}, {Key: "created_at", Value: 1}}},
		{
			Keys:    bson.D{{Key: "expires_at", Value: 1}},
			Options: options.Index().SetExpireAfterSeconds(0),
		},
	})
	return err
}
