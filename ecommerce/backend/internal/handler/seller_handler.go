package handler

import (
	"net/http"

	"ecommerce/backend/internal/repository"
	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/v2/bson"
)

type SellerHandler struct {
	products *repository.ProductRepository
	orders   *repository.OrderRepository
}

func NewSellerHandler(products *repository.ProductRepository, orders *repository.OrderRepository) *SellerHandler {
	return &SellerHandler{products: products, orders: orders}
}

func (h *SellerHandler) Products(c *gin.Context) {
	products, err := h.products.FindBySeller(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load seller products"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": products, "message": "seller products loaded"})
}

func (h *SellerHandler) Orders(c *gin.Context) {
	orders, err := h.orders.FindBySeller(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load seller orders"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": orders, "message": "seller orders loaded"})
}

func (h *SellerHandler) Stats(c *gin.Context) {
	sellerID := c.MustGet("user_id").(bson.ObjectID)
	products, err := h.products.FindBySeller(c.Request.Context(), sellerID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load seller products"})
		return
	}
	orders, err := h.orders.FindBySeller(c.Request.Context(), sellerID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load seller orders"})
		return
	}
	revenue := 0.0
	for _, order := range orders {
		revenue += order.Total
	}
	c.JSON(http.StatusOK, gin.H{"data": gin.H{
		"total_products": len(products),
		"total_orders":   len(orders),
		"total_revenue":  revenue,
	}, "message": "seller stats loaded"})
}
