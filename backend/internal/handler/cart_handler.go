package handler

import (
	"net/http"

	"ecommerce/backend/internal/model"
	"ecommerce/backend/internal/repository"
	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/v2/bson"
)

type CartHandler struct {
	carts    *repository.CartRepository
	products *repository.ProductRepository
}

func NewCartHandler(carts *repository.CartRepository, products *repository.ProductRepository) *CartHandler {
	return &CartHandler{carts: carts, products: products}
}

func (h *CartHandler) Get(c *gin.Context) {
	cart, err := h.carts.Get(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load cart"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": cart, "message": "cart loaded"})
}

func (h *CartHandler) Add(c *gin.Context) {
	var req model.CartQuantityRequest
	if !bindCartQuantity(c, &req) {
		return
	}
	productID, _ := bson.ObjectIDFromHex(req.ProductID)
	product, err := h.products.FindByID(c.Request.Context(), productID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load product"})
		return
	}
	if product == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "product not found"})
		return
	}
	cart, err := h.carts.Get(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load cart"})
		return
	}
	image := ""
	if len(product.Images) > 0 {
		image = product.Images[0]
	}
	found := false
	for i := range cart.Items {
		if cart.Items[i].ProductID == productID {
			cart.Items[i].Quantity += req.Quantity
			found = true
		}
	}
	if !found {
		cart.Items = append(cart.Items, model.CartItem{ProductID: productID, Name: product.Name, Price: product.Price, Image: image, Quantity: req.Quantity})
	}
	h.saveCart(c, cart, "cart updated")
}

func (h *CartHandler) Update(c *gin.Context) {
	var req model.CartQuantityRequest
	if !bindCartQuantity(c, &req) {
		return
	}
	productID, _ := bson.ObjectIDFromHex(req.ProductID)
	cart, err := h.carts.Get(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load cart"})
		return
	}
	for i := range cart.Items {
		if cart.Items[i].ProductID == productID {
			cart.Items[i].Quantity = req.Quantity
			h.saveCart(c, cart, "cart updated")
			return
		}
	}
	c.JSON(http.StatusNotFound, gin.H{"error": "cart item not found"})
}

func (h *CartHandler) Remove(c *gin.Context) {
	productID, err := bson.ObjectIDFromHex(c.Param("product_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid product id"})
		return
	}
	cart, err := h.carts.Get(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load cart"})
		return
	}
	next := make([]model.CartItem, 0, len(cart.Items))
	for _, item := range cart.Items {
		if item.ProductID != productID {
			next = append(next, item)
		}
	}
	cart.Items = next
	h.saveCart(c, cart, "item removed")
}

func (h *CartHandler) Clear(c *gin.Context) {
	cart, err := h.carts.Get(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load cart"})
		return
	}
	cart.Items = []model.CartItem{}
	h.saveCart(c, cart, "cart cleared")
}

func (h *CartHandler) saveCart(c *gin.Context, cart *model.Cart, message string) {
	if err := h.carts.Save(c.Request.Context(), cart); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to save cart"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": cart, "message": message})
}

func bindCartQuantity(c *gin.Context, req *model.CartQuantityRequest) bool {
	if err := c.ShouldBindJSON(req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return false
	}
	if _, err := bson.ObjectIDFromHex(req.ProductID); err != nil || req.Quantity < 1 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "valid product_id and quantity >= 1 are required"})
		return false
	}
	return true
}
