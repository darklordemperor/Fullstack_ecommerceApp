package handler

import (
	"net/http"
	"strconv"
	"strings"

	"ecommerce/backend/internal/httpx"
	"ecommerce/backend/internal/model"
	"ecommerce/backend/internal/usecase"
	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/v2/bson"
)

type ProductHandler struct {
	products *usecase.ProductUsecase
}

func NewProductHandler(products *usecase.ProductUsecase) *ProductHandler {
	return &ProductHandler{products: products}
}

func (h *ProductHandler) List(c *gin.Context) {
	page := queryInt(c, "page", 1)
	limit := queryInt(c, "limit", 20)
	products, err := h.products.List(c.Request.Context(), c.Query("category"), c.Query("search"), page, limit)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": products, "message": "products loaded"})
}

func (h *ProductHandler) Detail(c *gin.Context) {
	id, err := bson.ObjectIDFromHex(c.Param("id"))
	if err != nil {
		httpx.Error(c, http.StatusBadRequest, httpx.CodeBadRequest, "invalid product id")
		return
	}
	product, err := h.products.Get(c.Request.Context(), id)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": product, "message": "product loaded"})
}

func (h *ProductHandler) Create(c *gin.Context) {
	var req model.ProductRequest
	if !bindProduct(c, &req) {
		return
	}
	product, err := h.products.Create(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID), req)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"data": product, "message": "product created"})
}

func (h *ProductHandler) Update(c *gin.Context) {
	id, err := bson.ObjectIDFromHex(c.Param("id"))
	if err != nil {
		httpx.Error(c, http.StatusBadRequest, httpx.CodeBadRequest, "invalid product id")
		return
	}
	var req model.ProductRequest
	if !bindProduct(c, &req) {
		return
	}
	product, err := h.products.Update(c.Request.Context(), id, c.MustGet("user_id").(bson.ObjectID), req)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": product, "message": "product updated"})
}

func (h *ProductHandler) Delete(c *gin.Context) {
	id, err := bson.ObjectIDFromHex(c.Param("id"))
	if err != nil {
		httpx.Error(c, http.StatusBadRequest, httpx.CodeBadRequest, "invalid product id")
		return
	}
	if err := h.products.Delete(c.Request.Context(), id, c.MustGet("user_id").(bson.ObjectID)); err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": nil, "message": "product deleted"})
}

// queryInt reads an integer query parameter, falling back to def when it is
// absent or malformed.
func queryInt(c *gin.Context, key string, def int) int {
	if parsed, err := strconv.Atoi(c.Query(key)); err == nil {
		return parsed
	}
	return def
}

// bindProduct decodes and shape-validates a product payload (a delivery
// concern). Business rules live in the usecase.
func bindProduct(c *gin.Context, req *model.ProductRequest) bool {
	if err := c.ShouldBindJSON(req); err != nil {
		httpx.Error(c, http.StatusBadRequest, httpx.CodeBadRequest, "invalid request body")
		return false
	}
	if strings.TrimSpace(req.Name) == "" || strings.TrimSpace(req.Description) == "" || req.Price <= 0 || req.Price > 1000000 || req.Stock < 0 || req.Stock > 99 {
		httpx.Error(c, http.StatusBadRequest, httpx.CodeValidation, "name, description, price 1-1,000,000, and stock 0-99 are required")
		return false
	}
	if req.Images == nil {
		req.Images = []string{}
	}
	return true
}
