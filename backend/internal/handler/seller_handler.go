package handler

import (
	"net/http"

	"ecommerce/backend/internal/usecase"
	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/v2/bson"
)

type SellerHandler struct {
	seller *usecase.SellerUsecase
}

func NewSellerHandler(seller *usecase.SellerUsecase) *SellerHandler {
	return &SellerHandler{seller: seller}
}

func (h *SellerHandler) Products(c *gin.Context) {
	products, err := h.seller.Products(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID))
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": products, "message": "seller products loaded"})
}

func (h *SellerHandler) Orders(c *gin.Context) {
	orders, err := h.seller.Orders(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID))
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": orders, "message": "seller orders loaded"})
}

func (h *SellerHandler) Stats(c *gin.Context) {
	stats, err := h.seller.Stats(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID))
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": stats, "message": "seller stats loaded"})
}
