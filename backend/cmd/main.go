package main

import (
	"context"
	"log"
	"time"

	"ecommerce/backend/internal/config"
	"ecommerce/backend/internal/db"
	"ecommerce/backend/internal/handler"
	"ecommerce/backend/internal/middleware"
	"ecommerce/backend/internal/model"
	"ecommerce/backend/internal/repository"
	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
)

func main() {
	cfg := config.Load()
	mongoDB, err := db.Connect(cfg.MongoURI, cfg.MongoDB)
	if err != nil {
		log.Fatalf("failed to connect to MongoDB: %v", err)
	}

	userRepo := repository.NewUserRepository(mongoDB.Database)
	productRepo := repository.NewProductRepository(mongoDB.Database)
	cartRepo := repository.NewCartRepository(mongoDB.Database)
	orderRepo := repository.NewOrderRepository(mongoDB.Database)

	if err := seedDefaultTestUser(userRepo); err != nil {
		log.Fatalf("failed to seed default test user: %v", err)
	}

	authHandler := handler.NewAuthHandler(userRepo, cfg.JWTSecret)
	userHandler := handler.NewUserHandler(userRepo)
	productHandler := handler.NewProductHandler(productRepo, userRepo)
	cartHandler := handler.NewCartHandler(cartRepo, productRepo, userRepo, orderRepo)
	sellerHandler := handler.NewSellerHandler(productRepo, orderRepo)
	adminHandler := handler.NewAdminHandler(userRepo, productRepo, orderRepo)

	router := gin.Default()
	router.Use(cors.New(cors.Config{
		AllowOrigins: []string{
			"http://localhost:8082",
			"http://127.0.0.1:8082",
			"http://localhost:3000",
			"http://127.0.0.1:3000",
		},
		AllowMethods: []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders: []string{"Origin", "Content-Type", "Accept", "Authorization"},
	}))

	api := router.Group("/api")
	auth := api.Group("/auth")
	auth.POST("/register", authHandler.Register)
	auth.POST("/login", authHandler.Login)

	users := api.Group("/users", middleware.Auth(cfg.JWTSecret))
	users.GET("/me", userHandler.Me)
	users.PUT("/me", userHandler.UpdateMe)
	users.POST("/seller-apply", userHandler.SellerApply)
	users.POST("/seller-approve/:id", userHandler.SellerApprove)

	products := api.Group("/products")
	products.GET("", productHandler.List)
	products.GET("/:id", productHandler.Detail)
	products.POST("", middleware.Auth(cfg.JWTSecret), middleware.RequireRole("seller", userRepo), productHandler.Create)
	products.PUT("/:id", middleware.Auth(cfg.JWTSecret), middleware.RequireRole("seller", userRepo), productHandler.Update)
	products.DELETE("/:id", middleware.Auth(cfg.JWTSecret), middleware.RequireRole("seller", userRepo), productHandler.Delete)

	cart := api.Group("/cart", middleware.Auth(cfg.JWTSecret))
	cart.GET("", cartHandler.Get)
	cart.POST("/add", cartHandler.Add)
	cart.PUT("/update", cartHandler.Update)
	cart.DELETE("/remove/:product_id", cartHandler.Remove)
	cart.DELETE("/clear", cartHandler.Clear)
	cart.POST("/checkout", cartHandler.Checkout)
	cart.POST("/buy-now", cartHandler.BuyNow)

	seller := api.Group("/seller", middleware.Auth(cfg.JWTSecret), middleware.RequireRole("seller", userRepo))
	seller.GET("/products", sellerHandler.Products)
	seller.GET("/orders", sellerHandler.Orders)
	seller.GET("/stats", sellerHandler.Stats)

	admin := api.Group("/admin", middleware.Auth(cfg.JWTSecret), middleware.RequireRole("admin", userRepo))
	admin.GET("/stats", adminHandler.Stats)
	admin.GET("/users", adminHandler.Users)
	admin.GET("/products", adminHandler.Products)
	admin.PUT("/users/:id/ban", adminHandler.SetUserBanned)
	admin.DELETE("/products/:id", adminHandler.DeleteProduct)

	if err := router.Run(":" + cfg.Port); err != nil {
		log.Fatalf("server stopped: %v", err)
	}
}

func seedDefaultTestUser(userRepo *repository.UserRepository) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	users := []*model.User{
		{
			Name:         "Test",
			Lastname:     "Customer",
			Age:          25,
			Gender:       "Other",
			Email:        "test@example.com",
			Address:      "Bangkok, Thailand",
			Role:         []string{"customer"},
			SellerStatus: "none",
		},
		{
			Name:           "Test",
			Lastname:       "Seller",
			Age:            30,
			Gender:         "Other",
			Email:          "seller@example.com",
			Address:        "Bangkok, Thailand",
			Role:           []string{"customer", "seller"},
			ShopName:       "Demo Seller Shop",
			ShopLocation:   "Bangkok",
			TaxPayerNumber: "TAX-DEMO-001",
			SellerStatus:   "approved",
		},
		{
			Name:         "Admin",
			Lastname:     "User",
			Age:          30,
			Gender:       "Other",
			Email:        "admin@example.com",
			Address:      "Bangkok, Thailand",
			Role:         []string{"admin"},
			SellerStatus: "none",
		},
	}

	for _, user := range users {
		if err := seedUser(ctx, userRepo, user); err != nil {
			return err
		}
	}
	return nil
}

func seedUser(ctx context.Context, userRepo *repository.UserRepository, user *model.User) error {
	existing, err := userRepo.FindByEmail(ctx, user.Email)
	if err != nil {
		return err
	}
	if existing != nil {
		log.Printf("default test user ready: %s", user.Email)
		return nil
	}

	hash, err := bcrypt.GenerateFromPassword([]byte("abc12345"), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	user.Password = string(hash)
	if err := userRepo.Create(ctx, user); err != nil {
		return err
	}
	log.Printf("seeded default test user: %s", user.Email)
	return nil
}
