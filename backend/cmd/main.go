package main

import (
	"log"

	"ecommerce/backend/internal/config"
	"ecommerce/backend/internal/db"
	"ecommerce/backend/internal/handler"
	"ecommerce/backend/internal/middleware"
	"ecommerce/backend/internal/repository"
	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
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

	authHandler := handler.NewAuthHandler(userRepo, cfg.JWTSecret)
	userHandler := handler.NewUserHandler(userRepo)
	productHandler := handler.NewProductHandler(productRepo, userRepo)
	cartHandler := handler.NewCartHandler(cartRepo, productRepo)
	sellerHandler := handler.NewSellerHandler(productRepo, orderRepo)

	router := gin.Default()
	router.Use(cors.Default())

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

	seller := api.Group("/seller", middleware.Auth(cfg.JWTSecret), middleware.RequireRole("seller", userRepo))
	seller.GET("/products", sellerHandler.Products)
	seller.GET("/orders", sellerHandler.Orders)
	seller.GET("/stats", sellerHandler.Stats)

	if err := router.Run(":" + cfg.Port); err != nil {
		log.Fatalf("server stopped: %v", err)
	}
}
