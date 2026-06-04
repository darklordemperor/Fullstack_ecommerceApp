package repository

import (
	"context"

	"ecommerce/backend/internal/model"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
)

type OrderRepository struct {
	collection *mongo.Collection
}

func NewOrderRepository(db *mongo.Database) *OrderRepository {
	return &OrderRepository{collection: db.Collection("orders")}
}

func (r *OrderRepository) FindBySeller(ctx context.Context, sellerID bson.ObjectID) ([]model.Order, error) {
	cursor, err := r.collection.Find(ctx, bson.M{"seller_id": sellerID})
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)
	var orders []model.Order
	if err := cursor.All(ctx, &orders); err != nil {
		return nil, err
	}
	return orders, nil
}
