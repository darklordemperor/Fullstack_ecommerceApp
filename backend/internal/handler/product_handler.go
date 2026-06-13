package handler

import (
	"net/http"
	"strconv"
	"strings"

	"ecommerce/backend/internal/model"
	"ecommerce/backend/internal/repository"
	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/v2/bson"
)

type ProductHandler struct {
	products *repository.ProductRepository
	users    *repository.UserRepository
}

func NewProductHandler(products *repository.ProductRepository, users *repository.UserRepository) *ProductHandler {
	return &ProductHandler{products: products, users: users}
}

func (h *ProductHandler) List(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	products, err := h.products.FindAll(c.Request.Context(), c.Query("category"), c.Query("search"), page, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to list products"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": products, "message": "products loaded"})
}

func (h *ProductHandler) Detail(c *gin.Context) {
	product, ok := h.loadProduct(c)
	if !ok {
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": product, "message": "product loaded"})
}

func (h *ProductHandler) Create(c *gin.Context) {
	var req model.ProductRequest
	if !bindProduct(c, &req) {
		return
	}
	userID := c.MustGet("user_id").(bson.ObjectID)
	user, err := h.users.FindByID(c.Request.Context(), userID)
	if err != nil || user == nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load seller"})
		return
	}
	product := &model.Product{
		ID: bson.NewObjectID(), SellerID: userID, SellerName: user.ShopName,
		Name: strings.TrimSpace(req.Name), Description: strings.TrimSpace(req.Description),
		Price: req.Price, Stock: req.Stock, Category: req.Category, Images: req.Images,
	}
	if product.SellerName == "" {
		product.SellerName = user.Name + " " + user.Lastname
	}
	if err := h.products.Create(c.Request.Context(), product); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create product"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"data": product, "message": "product created"})
}

func (h *ProductHandler) Update(c *gin.Context) {
	id, err := bson.ObjectIDFromHex(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid product id"})
		return
	}
	var req model.ProductRequest
	if !bindProduct(c, &req) {
		return
	}
	updated, err := h.products.Update(c.Request.Context(), id, c.MustGet("user_id").(bson.ObjectID), req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update product"})
		return
	}
	if !updated {
		c.JSON(http.StatusNotFound, gin.H{"error": "product not found or not owned by seller"})
		return
	}
	product, _ := h.products.FindByID(c.Request.Context(), id)
	c.JSON(http.StatusOK, gin.H{"data": product, "message": "product updated"})
}

func (h *ProductHandler) Delete(c *gin.Context) {
	id, err := bson.ObjectIDFromHex(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid product id"})
		return
	}
	deleted, err := h.products.Delete(c.Request.Context(), id, c.MustGet("user_id").(bson.ObjectID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to delete product"})
		return
	}
	if !deleted {
		c.JSON(http.StatusNotFound, gin.H{"error": "product not found or not owned by seller"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": nil, "message": "product deleted"})
}

func (h *ProductHandler) loadProduct(c *gin.Context) (*model.Product, bool) {
	id, err := bson.ObjectIDFromHex(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid product id"})
		return nil, false
	}
	product, err := h.products.FindByID(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load product"})
		return nil, false
	}
	if product == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "product not found"})
		return nil, false
	}
	return product, true
}

func bindProduct(c *gin.Context, req *model.ProductRequest) bool {
	if err := c.ShouldBindJSON(req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return false
	}
	if strings.TrimSpace(req.Name) == "" || strings.TrimSpace(req.Description) == "" || req.Price <= 0 || req.Price > 1000000 || req.Stock < 0 || req.Stock > 99 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "name, description, price 1-1,000,000, and stock 0-99 are required"})
		return false
	}
	if req.Images == nil {
		req.Images = []string{}
	}
	return true
}
