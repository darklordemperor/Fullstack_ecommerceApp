package handler

import (
	"net/http"
	"regexp"
	"strings"

	"ecommerce/backend/internal/httpx"
	"ecommerce/backend/internal/model"
	"ecommerce/backend/internal/usecase"
	"github.com/gin-gonic/gin"
)

// AuthHandler is a thin delivery adapter: it decodes the request, validates its
// shape, delegates business rules to the usecase, and maps the result (or a
// domain error) to an HTTP response. It holds no business logic itself.
type AuthHandler struct {
	auth *usecase.AuthUsecase
}

func NewAuthHandler(auth *usecase.AuthUsecase) *AuthHandler {
	return &AuthHandler{auth: auth}
}

func (h *AuthHandler) Register(c *gin.Context) {
	var req model.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.Error(c, http.StatusBadRequest, httpx.CodeBadRequest, "invalid request body")
		return
	}
	if errorsMap := validateRegister(req); len(errorsMap) > 0 {
		httpx.ValidationError(c, errorsMap)
		return
	}

	user, err := h.auth.Register(c.Request.Context(), req)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"data": user, "message": "user registered successfully"})
}

func (h *AuthHandler) Login(c *gin.Context) {
	var req model.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.Error(c, http.StatusBadRequest, httpx.CodeBadRequest, "invalid request body")
		return
	}

	tokens, user, err := h.auth.Login(c.Request.Context(), req.Email, req.Password)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"data":    gin.H{"token": tokens.Access, "refresh_token": tokens.Refresh, "user": user},
		"message": "login successful",
	})
}

// Refresh exchanges a valid refresh token for a new access + refresh pair.
func (h *AuthHandler) Refresh(c *gin.Context) {
	var req struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := c.ShouldBindJSON(&req); err != nil || strings.TrimSpace(req.RefreshToken) == "" {
		httpx.Error(c, http.StatusBadRequest, httpx.CodeBadRequest, "refresh_token is required")
		return
	}
	tokens, user, err := h.auth.Refresh(c.Request.Context(), req.RefreshToken)
	if err != nil {
		respondError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"data":    gin.H{"token": tokens.Access, "refresh_token": tokens.Refresh, "user": user},
		"message": "token refreshed",
	})
}

// Logout revokes the given refresh token. A missing token is a no-op success so
// the client can always clear local state.
func (h *AuthHandler) Logout(c *gin.Context) {
	var req struct {
		RefreshToken string `json:"refresh_token"`
	}
	_ = c.ShouldBindJSON(&req)
	if strings.TrimSpace(req.RefreshToken) != "" {
		if err := h.auth.Logout(c.Request.Context(), req.RefreshToken); err != nil {
			respondError(c, err)
			return
		}
	}
	c.JSON(http.StatusOK, gin.H{"data": nil, "message": "logged out"})
}

func validateRegister(req model.RegisterRequest) map[string]string {
	errorsMap := map[string]string{}
	if strings.TrimSpace(req.Name) == "" {
		errorsMap["name"] = "name is required"
	}
	if strings.TrimSpace(req.Lastname) == "" {
		errorsMap["lastname"] = "lastname is required"
	}
	if req.Age < 18 {
		errorsMap["age"] = "age must be at least 18"
	}
	if strings.TrimSpace(req.Gender) == "" {
		errorsMap["gender"] = "gender is required"
	}
	if strings.TrimSpace(req.Address) == "" {
		errorsMap["address"] = "address is required"
	}
	if !regexp.MustCompile(`^[^\s@]+@[^\s@]+\.[^\s@]+$`).MatchString(strings.TrimSpace(req.Email)) {
		errorsMap["email"] = "valid email is required"
	}
	if !regexp.MustCompile(`^[a-z0-9]{8,}$`).MatchString(req.Password) {
		errorsMap["password"] = "password must use lowercase letters and numbers only, min 8 characters"
	}
	if req.ConfirmPassword == "" {
		errorsMap["confirm_password"] = "confirm password is required"
	} else if req.ConfirmPassword != req.Password {
		errorsMap["confirm_password"] = "passwords must match"
	}
	return errorsMap
}
