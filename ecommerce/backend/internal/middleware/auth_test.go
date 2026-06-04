package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/v2/bson"
)

func TestGenerateTokenAndAuthMiddlewareInjectsClaims(t *testing.T) {
	gin.SetMode(gin.TestMode)

	secret := "unit-test-secret"
	userID := bson.NewObjectID()
	token, err := GenerateToken(secret, userID.Hex(), "seller@example.com", []string{"customer", "seller"})
	if err != nil {
		t.Fatalf("GenerateToken returned error: %v", err)
	}

	router := gin.New()
	router.GET("/protected", Auth(secret), func(c *gin.Context) {
		gotID := c.MustGet("user_id").(bson.ObjectID)
		if gotID != userID {
			t.Fatalf("expected user id %s, got %s", userID.Hex(), gotID.Hex())
		}
		roles := c.MustGet("role").([]string)
		if len(roles) != 2 || roles[0] != "customer" || roles[1] != "seller" {
			t.Fatalf("unexpected roles: %v", roles)
		}
		c.JSON(http.StatusOK, gin.H{"ok": true})
	})

	req := httptest.NewRequest(http.MethodGet, "/protected", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d body=%s", rec.Code, rec.Body.String())
	}
}

func TestAuthMiddlewareRejectsMissingBearerToken(t *testing.T) {
	gin.SetMode(gin.TestMode)

	router := gin.New()
	router.GET("/protected", Auth("secret"), func(c *gin.Context) {
		t.Fatal("handler should not run without token")
	})

	req := httptest.NewRequest(http.MethodGet, "/protected", nil)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected status 401, got %d", rec.Code)
	}
}

func TestAuthMiddlewareRejectsInvalidToken(t *testing.T) {
	gin.SetMode(gin.TestMode)

	router := gin.New()
	router.GET("/protected", Auth("secret"), func(c *gin.Context) {
		t.Fatal("handler should not run for invalid token")
	})

	req := httptest.NewRequest(http.MethodGet, "/protected", nil)
	req.Header.Set("Authorization", "Bearer invalid-token")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected status 401, got %d", rec.Code)
	}
}
