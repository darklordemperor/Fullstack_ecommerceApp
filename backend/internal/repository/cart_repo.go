package repository

import (
	"context"
	"time"

	"ecommerce/backend/internal/model"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

type CartRepository struct {
	collection *mongo.Collection
}

func NewCartRepository(db *mongo.Database) *CartRepository {
	return &CartRepository{collection: db.Collection("carts")}
}

func (r *CartRepository) Get(ctx context.Context, userID bson.ObjectID) (*model.Cart, error) {
	var cart model.Cart
	err := r.collection.FindOne(ctx, bson.M{"user_id": userID}).Decode(&cart)
	if err == mongo.ErrNoDocuments {
		cart = model.Cart{ID: bson.NewObjectID(), UserID: userID, Items: []model.CartItem{}, UpdatedAt: time.Now()}
		_, err = r.collection.InsertOne(ctx, cart)
	}
	return &cart, err
}

func (r *CartRepository) Save(ctx context.Context, cart *model.Cart) error {
	cart.UpdatedAt = time.Now()
	_, err := r.collection.ReplaceOne(ctx, bson.M{"user_id": cart.UserID}, cart, options.Replace().SetUpsert(true))
	return err
}
