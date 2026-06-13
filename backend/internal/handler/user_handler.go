package handler

import (
	"net/http"
	"strings"

	"ecommerce/backend/internal/model"
	"ecommerce/backend/internal/repository"
	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/v2/bson"
)

type UserHandler struct {
	users *repository.UserRepository
}

func NewUserHandler(users *repository.UserRepository) *UserHandler {
	return &UserHandler{users: users}
}

func (h *UserHandler) Me(c *gin.Context) {
	user, err := h.users.FindByID(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load profile"})
		return
	}
	if user == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": user, "message": "profile loaded"})
}

func (h *UserHandler) UpdateMe(c *gin.Context) {
	var req model.UpdateProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}
	if strings.TrimSpace(req.Name) == "" || strings.TrimSpace(req.Lastname) == "" || req.Age < 18 || strings.TrimSpace(req.Gender) == "" || strings.TrimSpace(req.Address) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "name, lastname, age >= 18, gender, and address are required"})
		return
	}
	req.Name = strings.TrimSpace(req.Name)
	req.Lastname = strings.TrimSpace(req.Lastname)
	req.Gender = strings.TrimSpace(req.Gender)
	req.Address = strings.TrimSpace(req.Address)
	req.ProfileImage = strings.TrimSpace(req.ProfileImage)
	if err := h.users.UpdateProfile(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID), req); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update profile"})
		return
	}
	h.Me(c)
}

func (h *UserHandler) SellerApply(c *gin.Context) {
	var req model.SellerApplyRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}
	if strings.TrimSpace(req.ShopName) == "" || strings.TrimSpace(req.ShopLocation) == "" || strings.TrimSpace(req.TaxPayerNumber) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "shop_name, shop_location, and tax_payer_number are required"})
		return
	}
	if err := h.users.ApplySeller(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID), req); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to submit seller application"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": nil, "message": "seller application submitted"})
}

func (h *UserHandler) SellerApprove(c *gin.Context) {
	id, err := bson.ObjectIDFromHex(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user id"})
		return
	}
	if err := h.users.ApproveSeller(c.Request.Context(), id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to approve seller"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": gin.H{"user_id": id.Hex()}, "message": "seller approved"})
}
