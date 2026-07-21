package repository

import (
	"context"
	"errors"
	"time"

	"ecommerce/backend/internal/domain"
	"ecommerce/backend/internal/model"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
)

// Compile-time proof the MongoDB implementation satisfies the domain port.
var _ domain.RefreshTokenRepository = (*RefreshTokenRepository)(nil)

type RefreshTokenRepository struct {
	collection *mongo.Collection
}

func NewRefreshTokenRepository(db *mongo.Database) *RefreshTokenRepository {
	return &RefreshTokenRepository{collection: db.Collection("refresh_tokens")}
}

func (r *RefreshTokenRepository) Create(ctx context.Context, token *model.RefreshToken) error {
	if token.ID.IsZero() {
		token.ID = bson.NewObjectID()
	}
	token.CreatedAt = time.Now()
	_, err := r.collection.InsertOne(ctx, token)
	return err
}

func (r *RefreshTokenRepository) FindByHash(ctx context.Context, hash string) (*model.RefreshToken, error) {
	var token model.RefreshToken
	err := r.collection.FindOne(ctx, bson.M{"token_hash": hash}).Decode(&token)
	if errors.Is(err, mongo.ErrNoDocuments) {
		return nil, nil
	}
	return &token, err
}

func (r *RefreshTokenRepository) Revoke(ctx context.Context, id bson.ObjectID) error {
	_, err := r.collection.UpdateOne(ctx, bson.M{"_id": id}, bson.M{"$set": bson.M{"revoked": true}})
	return err
}

func (r *RefreshTokenRepository) RevokeAllForUser(ctx context.Context, userID bson.ObjectID) error {
	_, err := r.collection.UpdateMany(ctx, bson.M{"user_id": userID}, bson.M{"$set": bson.M{"revoked": true}})
	return err
}
