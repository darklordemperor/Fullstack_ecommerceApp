package config

import (
	"log/slog"
	"os"
	"strconv"
	"time"
)

type Config struct {
	AppEnv          string
	MongoURI        string
	MongoDB         string
	JWTSecret       string
	Port            string
	MongoMaxPool    uint64
	MongoMinPool    uint64
	RequestTimeout  time.Duration
	RateLimitRPS    int
	RateLimitBurst  int
	AccessTokenTTL  time.Duration
	RefreshTokenTTL time.Duration
}

// defaultInsecureSecret is the built-in dev secret. Signing production tokens
// with it would let anyone forge a valid JWT, so validate() refuses to boot a
// prod build that still uses it.
const defaultInsecureSecret = "supersecretkey"

func Load() Config {
	cfg := Config{
		AppEnv:         getEnv("APP_ENV", "dev"),
		MongoURI:       getEnv("MONGO_URI", "mongodb://localhost:27017"),
		MongoDB:        getEnv("MONGO_DB", "ecommerce"),
		JWTSecret:      getEnv("JWT_SECRET", defaultInsecureSecret),
		Port:           getEnv("PORT", "8080"),
		MongoMaxPool:   getEnvUint("MONGO_MAX_POOL_SIZE", 100),
		MongoMinPool:   getEnvUint("MONGO_MIN_POOL_SIZE", 5),
		RequestTimeout: time.Duration(getEnvInt("REQUEST_TIMEOUT_SECONDS", 15)) * time.Second,
		RateLimitRPS:   getEnvInt("RATE_LIMIT_RPS", 20),
		RateLimitBurst: getEnvInt("RATE_LIMIT_BURST", 40),
		// Short-lived access token: the client silently refreshes it on 401
		// using the long-lived refresh token, so a leaked access token is only
		// useful for ~15 minutes.
		AccessTokenTTL:  time.Duration(getEnvInt("ACCESS_TOKEN_TTL_MINUTES", 15)) * time.Minute,
		RefreshTokenTTL: time.Duration(getEnvInt("REFRESH_TOKEN_TTL_HOURS", 720)) * time.Hour,
	}
	cfg.validate()
	return cfg
}

// validate fails fast on unsafe production configuration. Catching a missing or
// default secret at boot — rather than silently signing tokens with a public
// default — turns a silent security hole into a loud, obvious deploy failure.
func (c Config) validate() {
	if c.AppEnv != "prod" {
		if c.JWTSecret == defaultInsecureSecret {
			slog.Warn("using the built-in default JWT secret; set JWT_SECRET before production")
		}
		return
	}
	if problems := c.productionProblems(); len(problems) > 0 {
		slog.Error("invalid production configuration", "problems", problems)
		os.Exit(1)
	}
}

// productionProblems returns the reasons this config is unsafe to run as a
// production build (empty slice means safe). Kept pure and separate from
// validate() so it is unit-testable without triggering os.Exit.
func (c Config) productionProblems() []string {
	var problems []string
	if c.JWTSecret == "" || c.JWTSecret == defaultInsecureSecret {
		problems = append(problems, "JWT_SECRET must be set to a strong, non-default value")
	} else if len(c.JWTSecret) < 32 {
		problems = append(problems, "JWT_SECRET should be at least 32 characters")
	}
	return problems
}

func getEnv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	if value := os.Getenv(key); value != "" {
		if parsed, err := strconv.Atoi(value); err == nil {
			return parsed
		}
		slog.Warn("invalid integer env var; using fallback", "key", key, "value", value, "fallback", fallback)
	}
	return fallback
}

func getEnvUint(key string, fallback uint64) uint64 {
	if value := os.Getenv(key); value != "" {
		if parsed, err := strconv.ParseUint(value, 10, 64); err == nil {
			return parsed
		}
		slog.Warn("invalid unsigned env var; using fallback", "key", key, "value", value, "fallback", fallback)
	}
	return fallback
}
