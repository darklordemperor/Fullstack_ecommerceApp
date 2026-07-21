package handler

import (
	"net/http"

	"ecommerce/backend/internal/httpx"
	"ecommerce/backend/internal/model"
	"ecommerce/backend/internal/usecase"
	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/v2/bson"
)

type CartHandler struct {
	cart *usecase.CartUsecase
}

func NewCartHandler(cart *usecase.CartUsecase) *CartHandler {
	return &CartHandler{cart: cart}
}

func (h *CartHandler) Get(c *gin.Context) {
	cart, err := h.cart.Get(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID))
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": cart, "message": "cart loaded"})
}

func (h *CartHandler) Add(c *gin.Context) {
	var req model.CartQuantityRequest
	productID, ok := bindCartQuantity(c, &req)
	if !ok {
		return
	}
	cart, err := h.cart.Add(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID), productID, req.Quantity)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": cart, "message": "cart updated"})
}

func (h *CartHandler) Update(c *gin.Context) {
	var req model.CartQuantityRequest
	productID, ok := bindCartQuantity(c, &req)
	if !ok {
		return
	}
	cart, err := h.cart.Update(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID), productID, req.Quantity)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": cart, "message": "cart updated"})
}

func (h *CartHandler) Remove(c *gin.Context) {
	productID, err := bson.ObjectIDFromHex(c.Param("product_id"))
	if err != nil {
		httpx.Error(c, http.StatusBadRequest, httpx.CodeBadRequest, "invalid product id")
		return
	}
	cart, err := h.cart.Remove(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID), productID)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": cart, "message": "item removed"})
}

func (h *CartHandler) Clear(c *gin.Context) {
	cart, err := h.cart.Clear(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID))
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": cart, "message": "cart cleared"})
}

func (h *CartHandler) Checkout(c *gin.Context) {
	selected, ok := bindCheckoutProductIDs(c)
	if !ok {
		return
	}
	count, cart, err := h.cart.Checkout(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID), selected)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": gin.H{"orders_created": count, "cart": cart}, "message": "checkout complete"})
}

func (h *CartHandler) BuyNow(c *gin.Context) {
	var req model.CartQuantityRequest
	productID, ok := bindCartQuantity(c, &req)
	if !ok {
		return
	}
	count, err := h.cart.BuyNow(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID), productID, req.Quantity)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": gin.H{"orders_created": count}, "message": "checkout complete"})
}

// bindCartQuantity decodes and shape-validates a {product_id, quantity} body,
// returning the parsed product id so callers never re-parse it.
func bindCartQuantity(c *gin.Context, req *model.CartQuantityRequest) (bson.ObjectID, bool) {
	if err := c.ShouldBindJSON(req); err != nil {
		httpx.Error(c, http.StatusBadRequest, httpx.CodeBadRequest, "invalid request body")
		return bson.ObjectID{}, false
	}
	productID, err := bson.ObjectIDFromHex(req.ProductID)
	if err != nil || req.Quantity < 1 || req.Quantity > 99 {
		httpx.Error(c, http.StatusBadRequest, httpx.CodeValidation, "valid product_id and quantity 1-99 are required")
		return bson.ObjectID{}, false
	}
	return productID, true
}

// bindCheckoutProductIDs parses the optional {product_ids} selection. An empty
// body or empty list means "check out the whole cart" (nil selection).
func bindCheckoutProductIDs(c *gin.Context) (map[bson.ObjectID]bool, bool) {
	var req model.CartCheckoutRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		if err.Error() == "EOF" {
			return nil, true
		}
		httpx.Error(c, http.StatusBadRequest, httpx.CodeBadRequest, "invalid request body")
		return nil, false
	}
	if len(req.ProductIDs) == 0 {
		return nil, true
	}
	selected := make(map[bson.ObjectID]bool, len(req.ProductIDs))
	for _, rawID := range req.ProductIDs {
		id, err := bson.ObjectIDFromHex(rawID)
		if err != nil {
			httpx.Error(c, http.StatusBadRequest, httpx.CodeValidation, "valid product_ids are required")
			return nil, false
		}
		selected[id] = true
	}
	return selected, true
}
