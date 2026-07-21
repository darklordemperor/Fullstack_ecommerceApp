package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"ecommerce/backend/internal/config"
	"ecommerce/backend/internal/db"
	"ecommerce/backend/internal/handler"
	"ecommerce/backend/internal/metrics"
	"ecommerce/backend/internal/middleware"
	"ecommerce/backend/internal/model"
	"ecommerce/backend/internal/observability"
	"ecommerce/backend/internal/repository"
	"ecommerce/backend/internal/usecase"
	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
)

func main() {
	observability.Setup(slog.LevelInfo)

	cfg := config.Load()

	mongoDB, err := db.Connect(cfg.MongoURI, cfg.MongoDB, cfg.MongoMaxPool, cfg.MongoMinPool)
	if err != nil {
		slog.Error("failed to connect to MongoDB", "error", err)
		os.Exit(1)
	}

	{
		migCtx, migCancel := context.WithTimeout(context.Background(), 30*time.Second)
		err := db.RunMigrations(migCtx, mongoDB.Database)
		migCancel()
		if err != nil {
			slog.Error("failed to run database migrations", "error", err)
			os.Exit(1)
		}
	}

	userRepo := repository.NewUserRepository(mongoDB.Database)
	productRepo := repository.NewProductRepository(mongoDB.Database)
	cartRepo := repository.NewCartRepository(mongoDB.Database)
	orderRepo := repository.NewOrderRepository(mongoDB.Database)
	refreshTokenRepo := repository.NewRefreshTokenRepository(mongoDB.Database)

	if err := seedDefaultTestUser(userRepo); err != nil {
		slog.Error("failed to seed default test user", "error", err)
		os.Exit(1)
	}

	tokenIssuer := func(userID, email string, role []string, ttl time.Duration) (string, error) {
		return middleware.GenerateToken(cfg.JWTSecret, userID, email, role, ttl)
	}
	authHandler := handler.NewAuthHandler(usecase.NewAuthUsecase(
		userRepo, refreshTokenRepo, tokenIssuer, cfg.AccessTokenTTL, cfg.RefreshTokenTTL))
	userHandler := handler.NewUserHandler(usecase.NewUserUsecase(userRepo))
	productHandler := handler.NewProductHandler(usecase.NewProductUsecase(productRepo, userRepo))
	cartHandler := handler.NewCartHandler(usecase.NewCartUsecase(cartRepo, productRepo, userRepo, orderRepo))
	sellerHandler := handler.NewSellerHandler(usecase.NewSellerUsecase(productRepo, orderRepo))
	adminHandler := handler.NewAdminHandler(usecase.NewAdminUsecase(userRepo, productRepo, orderRepo))
	healthHandler := handler.NewHealthHandler(func(ctx context.Context) error {
		return mongoDB.Client.Ping(ctx, nil)
	})

	router := gin.New()
	// Order matters: assign a correlation id first so the recovery handler and
	// request logger can attach it; recover before the handlers run; time-box
	// and meter every request.
	router.Use(
		middleware.RequestID(),
		middleware.Recovery(),
		middleware.RequestLogger(),
		metrics.Middleware(),
		middleware.Timeout(cfg.RequestTimeout),
	)
	router.Use(cors.New(cors.Config{
		AllowOrigins: []string{
			"http://localhost:8082",
			"http://127.0.0.1:8082",
			"http://localhost:4200",
			"http://127.0.0.1:4200",
			"http://localhost:3000",
			"http://127.0.0.1:3000",
		},
		AllowMethods:  []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:  []string{"Origin", "Content-Type", "Accept", "Authorization", middleware.RequestIDHeader},
		ExposeHeaders: []string{middleware.RequestIDHeader},
	}))

	// Operational endpoints for load balancers, Kubernetes, and Prometheus.
	// Deliberately outside the rate limiter so probes/scrapes are never throttled.
	router.GET("/healthz", healthHandler.Live)
	router.GET("/readyz", healthHandler.Ready)
	router.GET("/metrics", metrics.Handler())

	// Per-client-IP rate limiting guards the versioned business API.
	rateLimiter := middleware.NewRateLimiter(float64(cfg.RateLimitRPS), float64(cfg.RateLimitBurst))
	api := router.Group("/api/v1", rateLimiter.Middleware())
	auth := api.Group("/auth")
	auth.POST("/register", authHandler.Register)
	auth.POST("/login", authHandler.Login)
	auth.POST("/refresh", authHandler.Refresh)
	auth.POST("/logout", authHandler.Logout)

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

	runServer(router, mongoDB, cfg)
}

// runServer starts the HTTP server and shuts it down gracefully on SIGINT /
// SIGTERM: it stops accepting new connections, lets in-flight requests finish
// (up to a deadline), then disconnects from MongoDB. Without this, a rolling
// deploy behind a load balancer would sever active requests mid-flight.
func runServer(router http.Handler, mongoDB *db.Mongo, cfg config.Config) {
	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           router,
		ReadHeaderTimeout: 10 * time.Second,
	}

	go func() {
		slog.Info("server started", "port", cfg.Port, "env", cfg.AppEnv)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			slog.Error("server failed", "error", err)
			os.Exit(1)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, os.Interrupt, syscall.SIGTERM)
	<-quit
	slog.Info("shutdown signal received; draining connections")

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		slog.Error("graceful shutdown failed", "error", err)
	}
	if err := mongoDB.Client.Disconnect(ctx); err != nil {
		slog.Error("mongo disconnect failed", "error", err)
	}
	slog.Info("server stopped cleanly")
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
		slog.Info("default test user ready", "email", user.Email)
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
	slog.Info("seeded default test user", "email", user.Email)
	return nil
}
