package repository

import (
	"context"
	"errors"
	"time"

	"ecommerce/backend/internal/model"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

type ProductRepository struct {
	collection *mongo.Collection
}

func NewProductRepository(db *mongo.Database) *ProductRepository {
	return &ProductRepository{collection: db.Collection("products")}
}

func (r *ProductRepository) Create(ctx context.Context, product *model.Product) error {
	now := time.Now()
	product.CreatedAt = now
	product.UpdatedAt = now
	_, err := r.collection.InsertOne(ctx, product)
	return err
}

func (r *ProductRepository) FindAll(ctx context.Context, category, search string, page, limit int) ([]model.Product, error) {
	filter := bson.M{}
	if category != "" && category != "All" {
		filter["category"] = category
	}
	if search != "" {
		filter["$or"] = []bson.M{
			{"name": bson.M{"$regex": search, "$options": "i"}},
			{"description": bson.M{"$regex": search, "$options": "i"}},
		}
	}
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 50 {
		limit = 20
	}
	opts := options.Find().SetSort(bson.D{{Key: "created_at", Value: -1}}).SetSkip(int64((page - 1) * limit)).SetLimit(int64(limit))
	cursor, err := r.collection.Find(ctx, filter, opts)
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)
	var products []model.Product
	if err := cursor.All(ctx, &products); err != nil {
		return nil, err
	}
	return products, nil
}

func (r *ProductRepository) FindByID(ctx context.Context, id bson.ObjectID) (*model.Product, error) {
	var product model.Product
	err := r.collection.FindOne(ctx, bson.M{"_id": id}).Decode(&product)
	if errors.Is(err, mongo.ErrNoDocuments) {
		return nil, nil
	}
	return &product, err
}

func (r *ProductRepository) FindBySeller(ctx context.Context, sellerID bson.ObjectID) ([]model.Product, error) {
	cursor, err := r.collection.Find(ctx, bson.M{"seller_id": sellerID}, options.Find().SetSort(bson.D{{Key: "updated_at", Value: -1}}))
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)
	var products []model.Product
	if err := cursor.All(ctx, &products); err != nil {
		return nil, err
	}
	return products, nil
}

func (r *ProductRepository) Update(ctx context.Context, id, sellerID bson.ObjectID, req model.ProductRequest) (bool, error) {
	result, err := r.collection.UpdateOne(ctx, bson.M{"_id": id, "seller_id": sellerID}, bson.M{"$set": bson.M{
		"name": req.Name, "description": req.Description, "price": req.Price,
		"stock": req.Stock, "category": req.Category, "images": req.Images, "updated_at": time.Now(),
	}})
	return result.MatchedCount > 0, err
}

func (r *ProductRepository) Delete(ctx context.Context, id, sellerID bson.ObjectID) (bool, error) {
	result, err := r.collection.DeleteOne(ctx, bson.M{"_id": id, "seller_id": sellerID})
	return result.DeletedCount > 0, err
}
