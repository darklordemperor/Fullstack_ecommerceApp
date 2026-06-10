package repository

import (
	"context"
	"errors"
	"strings"
	"time"

	"ecommerce/backend/internal/model"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
)

type UserRepository struct {
	collection *mongo.Collection
}

func NewUserRepository(db *mongo.Database) *UserRepository {
	return &UserRepository{collection: db.Collection("users")}
}

func (r *UserRepository) Create(ctx context.Context, user *model.User) error {
	if user.ID.IsZero() {
		user.ID = bson.NewObjectID()
	}
	user.Email = strings.ToLower(strings.TrimSpace(user.Email))
	user.CreatedAt = time.Now()
	_, err := r.collection.InsertOne(ctx, user)
	return err
}

func (r *UserRepository) FindByEmail(ctx context.Context, email string) (*model.User, error) {
	var user model.User
	err := r.collection.FindOne(ctx, bson.M{"email": strings.ToLower(strings.TrimSpace(email))}).Decode(&user)
	if errors.Is(err, mongo.ErrNoDocuments) {
		return nil, nil
	}
	return &user, err
}

func (r *UserRepository) FindByID(ctx context.Context, id bson.ObjectID) (*model.User, error) {
	var user model.User
	err := r.collection.FindOne(ctx, bson.M{"_id": id}).Decode(&user)
	if errors.Is(err, mongo.ErrNoDocuments) {
		return nil, nil
	}
	return &user, err
}

func (r *UserRepository) UpdateProfile(ctx context.Context, id bson.ObjectID, req model.UpdateProfileRequest) error {
	_, err := r.collection.UpdateOne(ctx, bson.M{"_id": id}, bson.M{"$set": bson.M{
		"name": req.Name, "lastname": req.Lastname, "age": req.Age,
	}})
	return err
}

func (r *UserRepository) ApplySeller(ctx context.Context, id bson.ObjectID, req model.SellerApplyRequest) error {
	_, err := r.collection.UpdateOne(ctx, bson.M{"_id": id}, bson.M{"$set": bson.M{
		"shop_name": req.ShopName, "shop_location": req.ShopLocation,
		"tax_payer_number": req.TaxPayerNumber, "seller_status": "pending",
	}})
	return err
}

func (r *UserRepository) ApproveSeller(ctx context.Context, id bson.ObjectID) error {
	_, err := r.collection.UpdateOne(ctx, bson.M{"_id": id}, bson.M{
		"$addToSet": bson.M{"role": "seller"},
		"$set":      bson.M{"seller_status": "approved"},
	})
	return err
}
