package handler

import (
	"net/http"

	"ecommerce/backend/internal/httpx"
	"ecommerce/backend/internal/usecase"
	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/v2/bson"
)

type AdminHandler struct {
	admin *usecase.AdminUsecase
}

func NewAdminHandler(admin *usecase.AdminUsecase) *AdminHandler {
	return &AdminHandler{admin: admin}
}

func (h *AdminHandler) Stats(c *gin.Context) {
	stats, err := h.admin.Stats(c.Request.Context())
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": stats, "message": "admin stats loaded"})
}

func (h *AdminHandler) Users(c *gin.Context) {
	users, err := h.admin.Users(c.Request.Context())
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": users, "message": "users loaded"})
}

func (h *AdminHandler) Products(c *gin.Context) {
	products, err := h.admin.Products(c.Request.Context())
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": products, "message": "products loaded"})
}

func (h *AdminHandler) SetUserBanned(c *gin.Context) {
	id, err := bson.ObjectIDFromHex(c.Param("id"))
	if err != nil {
		httpx.Error(c, http.StatusBadRequest, httpx.CodeBadRequest, "invalid user id")
		return
	}
	var req struct {
		Banned bool `json:"banned"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.Error(c, http.StatusBadRequest, httpx.CodeBadRequest, "invalid request body")
		return
	}
	if err := h.admin.SetUserBanned(c.Request.Context(), id, req.Banned); err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": gin.H{"user_id": id.Hex(), "banned": req.Banned}, "message": "user updated"})
}

func (h *AdminHandler) DeleteProduct(c *gin.Context) {
	id, err := bson.ObjectIDFromHex(c.Param("id"))
	if err != nil {
		httpx.Error(c, http.StatusBadRequest, httpx.CodeBadRequest, "invalid product id")
		return
	}
	if err := h.admin.DeleteProduct(c.Request.Context(), id); err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": nil, "message": "product deleted"})
}
