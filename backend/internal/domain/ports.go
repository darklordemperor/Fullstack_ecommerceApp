package domain

import (
	"context"

	"ecommerce/backend/internal/model"
	"go.mongodb.org/mongo-driver/v2/bson"
)

// UserRepository is the persistence port for user data. The usecase layer
// depends on this interface, never on the concrete MongoDB implementation, so
// business logic can be unit-tested with a fake and the datastore can be
// swapped without touching business rules.
//
// Note: bson.ObjectID currently leaks into the port because it is the app-wide
// id type. Introducing a storage-agnostic id is a deliberate later step; it is
// isolated here so that change stays mechanical.
type UserRepository interface {
	Create(ctx context.Context, user *model.User) error
	FindByEmail(ctx context.Context, email string) (*model.User, error)
	FindByID(ctx context.Context, id bson.ObjectID) (*model.User, error)
	FindAll(ctx context.Context) ([]model.User, error)
	SetBanned(ctx context.Context, id bson.ObjectID, banned bool) error
	UpdateProfile(ctx context.Context, id bson.ObjectID, req model.UpdateProfileRequest) error
	ApplySeller(ctx context.Context, id bson.ObjectID, req model.SellerApplyRequest) error
	ApproveSeller(ctx context.Context, id bson.ObjectID) error
}

// ProductRepository is the persistence port for products.
type ProductRepository interface {
	Create(ctx context.Context, product *model.Product) error
	FindAll(ctx context.Context, category, search string, page, limit int) ([]model.Product, error)
	FindAllAdmin(ctx context.Context) ([]model.Product, error)
	FindByID(ctx context.Context, id bson.ObjectID) (*model.Product, error)
	FindBySeller(ctx context.Context, sellerID bson.ObjectID) ([]model.Product, error)
	Update(ctx context.Context, id, sellerID bson.ObjectID, req model.ProductRequest) (bool, error)
	Delete(ctx context.Context, id, sellerID bson.ObjectID) (bool, error)
	DeleteAny(ctx context.Context, id bson.ObjectID) (bool, error)
}

// CartRepository is the persistence port for shopping carts.
type CartRepository interface {
	Get(ctx context.Context, userID bson.ObjectID) (*model.Cart, error)
	Save(ctx context.Context, cart *model.Cart) error
}

// OrderRepository is the persistence port for orders.
type OrderRepository interface {
	CreateMany(ctx context.Context, orders []model.Order) error
	FindBySeller(ctx context.Context, sellerID bson.ObjectID) ([]model.Order, error)
	FindAll(ctx context.Context) ([]model.Order, error)
}

// RefreshTokenRepository is the persistence port for refresh tokens.
type RefreshTokenRepository interface {
	Create(ctx context.Context, token *model.RefreshToken) error
	FindByHash(ctx context.Context, hash string) (*model.RefreshToken, error)
	Revoke(ctx context.Context, id bson.ObjectID) error
	RevokeAllForUser(ctx context.Context, userID bson.ObjectID) error
}
