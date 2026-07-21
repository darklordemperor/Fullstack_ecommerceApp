package repository

import (
	"context"
	"time"

	"ecommerce/backend/internal/domain"
	"ecommerce/backend/internal/model"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

// Compile-time proof the MongoDB implementation satisfies the domain port.
var _ domain.OrderRepository = (*OrderRepository)(nil)

// newestFirst sorts orders by creation time descending, matching the
// {seller_id/customer_id, created_at:-1} indexes so the sort is index-backed.
var newestFirst = options.Find().SetSort(bson.D{{Key: "created_at", Value: -1}})

type OrderRepository struct {
	collection *mongo.Collection
}

func NewOrderRepository(db *mongo.Database) *OrderRepository {
	return &OrderRepository{collection: db.Collection("orders")}
}

func (r *OrderRepository) CreateMany(ctx context.Context, orders []model.Order) error {
	if len(orders) == 0 {
		return nil
	}
	docs := make([]interface{}, len(orders))
	now := time.Now()
	for i := range orders {
		if orders[i].ID.IsZero() {
			orders[i].ID = bson.NewObjectID()
		}
		if orders[i].Status == "" {
			orders[i].Status = "paid"
		}
		orders[i].CreatedAt = now
		docs[i] = orders[i]
	}
	_, err := r.collection.InsertMany(ctx, docs)
	return err
}

func (r *OrderRepository) FindBySeller(ctx context.Context, sellerID bson.ObjectID) ([]model.Order, error) {
	cursor, err := r.collection.Find(ctx, bson.M{"seller_id": sellerID}, newestFirst)
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

func (r *OrderRepository) FindAll(ctx context.Context) ([]model.Order, error) {
	cursor, err := r.collection.Find(ctx, bson.M{}, newestFirst)
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
