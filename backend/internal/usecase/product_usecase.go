package usecase

import (
	"context"
	"strings"

	"ecommerce/backend/internal/domain"
	"ecommerce/backend/internal/model"
	"go.mongodb.org/mongo-driver/v2/bson"
)

// ProductUsecase holds storefront listing and seller product-CRUD rules.
type ProductUsecase struct {
	products domain.ProductRepository
	users    domain.UserRepository
}

func NewProductUsecase(products domain.ProductRepository, users domain.UserRepository) *ProductUsecase {
	return &ProductUsecase{products: products, users: users}
}

// List returns a page of storefront products.
func (u *ProductUsecase) List(ctx context.Context, category, search string, page, limit int) ([]model.Product, error) {
	return u.products.FindAll(ctx, category, search, page, limit)
}

// Get returns a single product or domain.ErrNotFound.
func (u *ProductUsecase) Get(ctx context.Context, id bson.ObjectID) (*model.Product, error) {
	product, err := u.products.FindByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if product == nil {
		return nil, domain.ErrNotFound
	}
	return product, nil
}

// Create publishes a new product for the seller, stamping the shop/display name
// from the seller's profile.
func (u *ProductUsecase) Create(ctx context.Context, sellerID bson.ObjectID, req model.ProductRequest) (*model.Product, error) {
	user, err := u.users.FindByID(ctx, sellerID)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, domain.ErrNotFound
	}

	sellerName := user.ShopName
	if sellerName == "" {
		sellerName = user.Name + " " + user.Lastname
	}
	product := &model.Product{
		ID:          bson.NewObjectID(),
		SellerID:    sellerID,
		SellerName:  sellerName,
		Name:        strings.TrimSpace(req.Name),
		Description: strings.TrimSpace(req.Description),
		Price:       req.Price,
		Stock:       req.Stock,
		Category:    req.Category,
		Images:      req.Images,
	}
	if err := u.products.Create(ctx, product); err != nil {
		return nil, err
	}
	return product, nil
}

// Update edits a product the seller owns, returning the fresh record or
// domain.ErrProductNotOwned when it does not exist or belongs to someone else.
func (u *ProductUsecase) Update(ctx context.Context, id, sellerID bson.ObjectID, req model.ProductRequest) (*model.Product, error) {
	updated, err := u.products.Update(ctx, id, sellerID, req)
	if err != nil {
		return nil, err
	}
	if !updated {
		return nil, domain.ErrProductNotOwned
	}
	return u.products.FindByID(ctx, id)
}

// Delete removes a product the seller owns.
func (u *ProductUsecase) Delete(ctx context.Context, id, sellerID bson.ObjectID) error {
	deleted, err := u.products.Delete(ctx, id, sellerID)
	if err != nil {
		return err
	}
	if !deleted {
		return domain.ErrProductNotOwned
	}
	return nil
}
