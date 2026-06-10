package config

import "os"

type Config struct {
	MongoURI  string
	MongoDB   string
	JWTSecret string
	Port      string
}

func Load() Config {
	return Config{
		MongoURI:  getEnv("MONGO_URI", "mongodb://localhost:27017"),
		MongoDB:   getEnv("MONGO_DB", "ecommerce"),
		JWTSecret: getEnv("JWT_SECRET", "supersecretkey"),
		Port:      getEnv("PORT", "8080"),
	}
}

func getEnv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
