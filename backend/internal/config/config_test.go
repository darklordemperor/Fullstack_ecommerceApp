package config

import "testing"

func TestProductionProblemsRejectsDefaultSecret(t *testing.T) {
	cfg := Config{AppEnv: "prod", JWTSecret: defaultInsecureSecret}
	if problems := cfg.productionProblems(); len(problems) == 0 {
		t.Fatal("expected the built-in default secret to be rejected in prod")
	}
}

func TestProductionProblemsRejectsShortSecret(t *testing.T) {
	cfg := Config{AppEnv: "prod", JWTSecret: "too-short"}
	if problems := cfg.productionProblems(); len(problems) == 0 {
		t.Fatal("expected a short secret to be rejected in prod")
	}
}

func TestProductionProblemsAcceptsStrongSecret(t *testing.T) {
	cfg := Config{AppEnv: "prod", JWTSecret: "a-32-char-or-longer-production-secret-value"}
	if problems := cfg.productionProblems(); len(problems) != 0 {
		t.Fatalf("expected a strong secret to pass, got %v", problems)
	}
}

func TestLoadUsesDefaultsInDevWithoutExiting(t *testing.T) {
	t.Setenv("APP_ENV", "dev")
	t.Setenv("JWT_SECRET", "")
	cfg := Load()
	if cfg.AppEnv != "dev" {
		t.Fatalf("expected dev env, got %q", cfg.AppEnv)
	}
	if cfg.MongoMaxPool == 0 || cfg.RequestTimeout == 0 {
		t.Fatalf("expected pool/timeout defaults to be populated, got %+v", cfg)
	}
}
