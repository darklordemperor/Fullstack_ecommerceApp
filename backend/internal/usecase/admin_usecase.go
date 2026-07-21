package usecase

import (
	"context"

	"ecommerce/backend/internal/domain"
	"ecommerce/backend/internal/model"
	"go.mongodb.org/mongo-driver/v2/bson"
)

// AdminStats is the platform-wide summary.
type AdminStats struct {
	TotalUsers    int     `json:"total_users"`
	TotalProducts int     `json:"total_products"`
	TotalOrders   int     `json:"total_orders"`
	TotalRevenue  float64 `json:"total_revenue"`
}

// AdminUsecase serves platform administration reads and moderation actions.
type AdminUsecase struct {
	users    domain.UserRepository
	products domain.ProductRepository
	orders   domain.OrderRepository
}

func NewAdminUsecase(users domain.UserRepository, products domain.ProductRepository, orders domain.OrderRepository) *AdminUsecase {
	return &AdminUsecase{users: users, products: products, orders: orders}
}

func (u *AdminUsecase) Stats(ctx context.Context) (AdminStats, error) {
	users, err := u.users.FindAll(ctx)
	if err != nil {
		return AdminStats{}, err
	}
	products, err := u.products.FindAllAdmin(ctx)
	if err != nil {
		return AdminStats{}, err
	}
	orders, err := u.orders.FindAll(ctx)
	if err != nil {
		return AdminStats{}, err
	}
	return AdminStats{
		TotalUsers:    len(users),
		TotalProducts: len(products),
		TotalOrders:   len(orders),
		TotalRevenue:  sumOrderTotals(orders),
	}, nil
}

func (u *AdminUsecase) Users(ctx context.Context) ([]model.User, error) {
	return u.users.FindAll(ctx)
}

func (u *AdminUsecase) Products(ctx context.Context) ([]model.Product, error) {
	return u.products.FindAllAdmin(ctx)
}

func (u *AdminUsecase) SetUserBanned(ctx context.Context, id bson.ObjectID, banned bool) error {
	return u.users.SetBanned(ctx, id, banned)
}

func (u *AdminUsecase) DeleteProduct(ctx context.Context, id bson.ObjectID) error {
	deleted, err := u.products.DeleteAny(ctx, id)
	if err != nil {
		return err
	}
	if !deleted {
		return domain.ErrNotFound
	}
	return nil
}
