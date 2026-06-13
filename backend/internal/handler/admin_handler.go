package handler

import (
	"net/http"

	"ecommerce/backend/internal/repository"
	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/v2/bson"
)

type AdminHandler struct {
	users    *repository.UserRepository
	products *repository.ProductRepository
	orders   *repository.OrderRepository
}

func NewAdminHandler(users *repository.UserRepository, products *repository.ProductRepository, orders *repository.OrderRepository) *AdminHandler {
	return &AdminHandler{users: users, products: products, orders: orders}
}

func (h *AdminHandler) Stats(c *gin.Context) {
	users, err := h.users.FindAll(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load users"})
		return
	}
	products, err := h.products.FindAllAdmin(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load products"})
		return
	}
	orders, err := h.orders.FindAll(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load orders"})
		return
	}
	revenue := 0.0
	for _, order := range orders {
		revenue += order.Total
	}
	c.JSON(http.StatusOK, gin.H{"data": gin.H{
		"total_users":    len(users),
		"total_products": len(products),
		"total_orders":   len(orders),
		"total_revenue":  revenue,
	}, "message": "admin stats loaded"})
}

func (h *AdminHandler) Users(c *gin.Context) {
	users, err := h.users.FindAll(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load users"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": users, "message": "users loaded"})
}

func (h *AdminHandler) Products(c *gin.Context) {
	products, err := h.products.FindAllAdmin(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load products"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": products, "message": "products loaded"})
}

func (h *AdminHandler) SetUserBanned(c *gin.Context) {
	id, err := bson.ObjectIDFromHex(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user id"})
		return
	}
	var req struct {
		Banned bool `json:"banned"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}
	if err := h.users.SetBanned(c.Request.Context(), id, req.Banned); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update user"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": gin.H{"user_id": id.Hex(), "banned": req.Banned}, "message": "user updated"})
}

func (h *AdminHandler) DeleteProduct(c *gin.Context) {
	id, err := bson.ObjectIDFromHex(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid product id"})
		return
	}
	deleted, err := h.products.DeleteAny(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to delete product"})
		return
	}
	if !deleted {
		c.JSON(http.StatusNotFound, gin.H{"error": "product not found"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": nil, "message": "product deleted"})
}
