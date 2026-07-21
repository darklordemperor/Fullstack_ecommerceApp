package handler

import (
	"net/http"
	"strings"

	"ecommerce/backend/internal/httpx"
	"ecommerce/backend/internal/model"
	"ecommerce/backend/internal/usecase"
	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/v2/bson"
)

type UserHandler struct {
	users *usecase.UserUsecase
}

func NewUserHandler(users *usecase.UserUsecase) *UserHandler {
	return &UserHandler{users: users}
}

func (h *UserHandler) Me(c *gin.Context) {
	user, err := h.users.Profile(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID))
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": user, "message": "profile loaded"})
}

func (h *UserHandler) UpdateMe(c *gin.Context) {
	var req model.UpdateProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.Error(c, http.StatusBadRequest, httpx.CodeBadRequest, "invalid request body")
		return
	}
	if strings.TrimSpace(req.Name) == "" || strings.TrimSpace(req.Lastname) == "" || req.Age < 18 || strings.TrimSpace(req.Gender) == "" || strings.TrimSpace(req.Address) == "" {
		httpx.Error(c, http.StatusBadRequest, httpx.CodeValidation, "name, lastname, age >= 18, gender, and address are required")
		return
	}
	user, err := h.users.UpdateProfile(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID), req)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": user, "message": "profile loaded"})
}

func (h *UserHandler) SellerApply(c *gin.Context) {
	var req model.SellerApplyRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.Error(c, http.StatusBadRequest, httpx.CodeBadRequest, "invalid request body")
		return
	}
	if strings.TrimSpace(req.ShopName) == "" || strings.TrimSpace(req.ShopLocation) == "" || strings.TrimSpace(req.TaxPayerNumber) == "" {
		httpx.Error(c, http.StatusBadRequest, httpx.CodeValidation, "shop_name, shop_location, and tax_payer_number are required")
		return
	}
	if err := h.users.ApplySeller(c.Request.Context(), c.MustGet("user_id").(bson.ObjectID), req); err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": nil, "message": "seller application submitted"})
}

func (h *UserHandler) SellerApprove(c *gin.Context) {
	id, err := bson.ObjectIDFromHex(c.Param("id"))
	if err != nil {
		httpx.Error(c, http.StatusBadRequest, httpx.CodeBadRequest, "invalid user id")
		return
	}
	if err := h.users.ApproveSeller(c.Request.Context(), id); err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": gin.H{"user_id": id.Hex()}, "message": "seller approved"})
}
