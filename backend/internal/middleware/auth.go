package middleware

import (
	"net/http"
	"strings"
	"time"

	"ecommerce/backend/internal/repository"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"go.mongodb.org/mongo-driver/v2/bson"
)

type Claims struct {
	UserID string   `json:"user_id"`
	Email  string   `json:"email"`
	Role   []string `json:"role"`
	jwt.RegisteredClaims
}

func GenerateToken(secret, userID, email string, role []string) (string, error) {
	claims := Claims{
		UserID: userID,
		Email:  email,
		Role:   role,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(7 * 24 * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString([]byte(secret))
}

func Auth(secret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "missing bearer token"})
			return
		}
		tokenString := strings.TrimPrefix(header, "Bearer ")
		claims := &Claims{}
		token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
			return []byte(secret), nil
		})
		if err != nil || !token.Valid {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid or expired token"})
			return
		}
		userID, err := bson.ObjectIDFromHex(claims.UserID)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid token subject"})
			return
		}
		c.Set("user_id", userID)
		c.Set("email", claims.Email)
		c.Set("role", claims.Role)
		c.Next()
	}
}

func RequireRole(role string, users *repository.UserRepository) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.MustGet("user_id").(bson.ObjectID)
		user, err := users.FindByID(c.Request.Context(), userID)
		if err != nil || user == nil || user.Banned {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "account is not allowed to perform this action"})
			return
		}
		roles, _ := c.Get("role")
		roleList, _ := roles.([]string)
		if !contains(roleList, role) {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "insufficient role"})
			return
		}
		if role == "seller" {
			if err != nil || user == nil || user.SellerStatus != "approved" {
				c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "seller approval required"})
				return
			}
		}
		c.Next()
	}
}

func contains(values []string, target string) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}
	return false
}
