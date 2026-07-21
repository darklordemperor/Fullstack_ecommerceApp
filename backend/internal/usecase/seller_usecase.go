package usecase

import (
	"context"

	"ecommerce/backend/internal/domain"
	"ecommerce/backend/internal/model"
	"go.mongodb.org/mongo-driver/v2/bson"
)

// SellerStats is the seller dashboard summary.
type SellerStats struct {
	TotalProducts int     `json:"total_products"`
	TotalOrders   int     `json:"total_orders"`
	TotalRevenue  float64 `json:"total_revenue"`
}

// SellerUsecase serves a seller's own products, orders, and aggregate stats.
type SellerUsecase struct {
	products domain.ProductRepository
	orders   domain.OrderRepository
}

func NewSellerUsecase(products domain.ProductRepository, orders domain.OrderRepository) *SellerUsecase {
	return &SellerUsecase{products: products, orders: orders}
}

func (u *SellerUsecase) Products(ctx context.Context, sellerID bson.ObjectID) ([]model.Product, error) {
	return u.products.FindBySeller(ctx, sellerID)
}

func (u *SellerUsecase) Orders(ctx context.Context, sellerID bson.ObjectID) ([]model.Order, error) {
	return u.orders.FindBySeller(ctx, sellerID)
}

func (u *SellerUsecase) Stats(ctx context.Context, sellerID bson.ObjectID) (SellerStats, error) {
	products, err := u.products.FindBySeller(ctx, sellerID)
	if err != nil {
		return SellerStats{}, err
	}
	orders, err := u.orders.FindBySeller(ctx, sellerID)
	if err != nil {
		return SellerStats{}, err
	}
	return SellerStats{
		TotalProducts: len(products),
		TotalOrders:   len(orders),
		TotalRevenue:  sumOrderTotals(orders),
	}, nil
}

func sumOrderTotals(orders []model.Order) float64 {
	revenue := 0.0
	for _, order := range orders {
		revenue += order.Total
	}
	return revenue
}
