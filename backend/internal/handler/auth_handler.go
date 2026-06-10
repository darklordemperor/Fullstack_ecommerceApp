package handler

import (
	"net/http"
	"regexp"
	"strings"

	"ecommerce/backend/internal/middleware"
	"ecommerce/backend/internal/model"
	"ecommerce/backend/internal/repository"
	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
)

type AuthHandler struct {
	users     *repository.UserRepository
	jwtSecret string
}

func NewAuthHandler(users *repository.UserRepository, jwtSecret string) *AuthHandler {
	return &AuthHandler{users: users, jwtSecret: jwtSecret}
}

func (h *AuthHandler) Register(c *gin.Context) {
	var req model.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}
	if errorsMap := validateRegister(req); len(errorsMap) > 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": errorsMap})
		return
	}
	existing, err := h.users.FindByEmail(c.Request.Context(), req.Email)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to check email"})
		return
	}
	if existing != nil {
		c.JSON(http.StatusConflict, gin.H{"error": "email already registered"})
		return
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to hash password"})
		return
	}
	user := &model.User{
		Name: strings.TrimSpace(req.Name), Lastname: strings.TrimSpace(req.Lastname),
		Age: req.Age, Email: strings.ToLower(strings.TrimSpace(req.Email)),
		Password: string(hash), Role: []string{"customer"},
	}
	if err := h.users.Create(c.Request.Context(), user); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create user"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"data": user, "message": "user registered successfully"})
}

func (h *AuthHandler) Login(c *gin.Context) {
	var req model.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}
	user, err := h.users.FindByEmail(c.Request.Context(), req.Email)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load user"})
		return
	}
	if user == nil || bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(req.Password)) != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid email or password"})
		return
	}
	token, err := middleware.GenerateToken(h.jwtSecret, user.ID.Hex(), user.Email, user.Role)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to generate token"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": gin.H{"token": token, "user": user}, "message": "login successful"})
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
