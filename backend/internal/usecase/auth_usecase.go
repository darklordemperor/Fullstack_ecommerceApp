// Package usecase holds application business logic. Each usecase depends only
// on domain ports (interfaces) and is free of gin, HTTP, and direct MongoDB
// access, so the rules can be unit-tested with fakes and reused across
// transports (HTTP today, gRPC/CLI tomorrow).
package usecase

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"strings"
	"time"

	"ecommerce/backend/internal/domain"
	"ecommerce/backend/internal/model"
	"golang.org/x/crypto/bcrypt"
)

// TokenIssuer signs a short-lived access token for a user. Injecting it (rather
// than calling the JWT/middleware package directly) keeps this layer free of
// infrastructure imports and lets tests pass a stub.
type TokenIssuer func(userID, email string, role []string, ttl time.Duration) (string, error)

// Tokens is an access token paired with the refresh token that renews it.
type Tokens struct {
	Access  string
	Refresh string
}

// AuthUsecase implements registration, login, and token refresh business rules.
type AuthUsecase struct {
	users      domain.UserRepository
	refresh    domain.RefreshTokenRepository
	issue      TokenIssuer
	accessTTL  time.Duration
	refreshTTL time.Duration
}

func NewAuthUsecase(
	users domain.UserRepository,
	refresh domain.RefreshTokenRepository,
	issue TokenIssuer,
	accessTTL, refreshTTL time.Duration,
) *AuthUsecase {
	return &AuthUsecase{
		users:      users,
		refresh:    refresh,
		issue:      issue,
		accessTTL:  accessTTL,
		refreshTTL: refreshTTL,
	}
}

// Register creates a customer account. Request-shape validation is a delivery
// concern handled at the HTTP layer; this method enforces the business rule
// that emails are unique and persists a bcrypt-hashed password.
func (u *AuthUsecase) Register(ctx context.Context, req model.RegisterRequest) (*model.User, error) {
	existing, err := u.users.FindByEmail(ctx, req.Email)
	if err != nil {
		return nil, err
	}
	if existing != nil {
		return nil, domain.ErrEmailAlreadyExists
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}

	user := &model.User{
		Name:         strings.TrimSpace(req.Name),
		Lastname:     strings.TrimSpace(req.Lastname),
		Age:          req.Age,
		Gender:       strings.TrimSpace(req.Gender),
		Address:      strings.TrimSpace(req.Address),
		ProfileImage: strings.TrimSpace(req.ProfileImage),
		Email:        strings.ToLower(strings.TrimSpace(req.Email)),
		Password:     string(hash),
		Role:         []string{"customer"},
	}
	if err := u.users.Create(ctx, user); err != nil {
		return nil, err
	}
	return user, nil
}

// Login verifies credentials and returns a fresh access + refresh token pair.
// It returns domain.ErrInvalidCredentials for both an unknown email and a wrong
// password, so the response never reveals which accounts exist.
func (u *AuthUsecase) Login(ctx context.Context, email, password string) (Tokens, *model.User, error) {
	user, err := u.users.FindByEmail(ctx, email)
	if err != nil {
		return Tokens{}, nil, err
	}
	if user == nil || bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(password)) != nil {
		return Tokens{}, nil, domain.ErrInvalidCredentials
	}
	if user.Banned {
		return Tokens{}, nil, domain.ErrAccountBanned
	}
	return u.issueTokens(ctx, user)
}

// Refresh exchanges a valid refresh token for a new access + refresh pair,
// rotating the refresh token (the presented one is revoked). Presenting an
// already-revoked token means it was rotated already — a sign of theft — so the
// whole family is revoked and the request rejected.
func (u *AuthUsecase) Refresh(ctx context.Context, refreshToken string) (Tokens, *model.User, error) {
	stored, err := u.refresh.FindByHash(ctx, hashToken(refreshToken))
	if err != nil {
		return Tokens{}, nil, err
	}
	if stored == nil {
		return Tokens{}, nil, domain.ErrInvalidRefreshToken
	}
	if stored.Revoked {
		_ = u.refresh.RevokeAllForUser(ctx, stored.UserID)
		return Tokens{}, nil, domain.ErrInvalidRefreshToken
	}
	if time.Now().After(stored.ExpiresAt) {
		return Tokens{}, nil, domain.ErrInvalidRefreshToken
	}

	user, err := u.users.FindByID(ctx, stored.UserID)
	if err != nil {
		return Tokens{}, nil, err
	}
	if user == nil || user.Banned {
		_ = u.refresh.Revoke(ctx, stored.ID)
		return Tokens{}, nil, domain.ErrInvalidRefreshToken
	}

	if err := u.refresh.Revoke(ctx, stored.ID); err != nil {
		return Tokens{}, nil, err
	}
	return u.issueTokens(ctx, user)
}

// Logout revokes the given refresh token so it can no longer be exchanged.
// Unknown tokens are treated as already logged out (no error).
func (u *AuthUsecase) Logout(ctx context.Context, refreshToken string) error {
	stored, err := u.refresh.FindByHash(ctx, hashToken(refreshToken))
	if err != nil {
		return err
	}
	if stored == nil {
		return nil
	}
	return u.refresh.Revoke(ctx, stored.ID)
}

// issueTokens mints an access token and persists a new (hashed) refresh token.
func (u *AuthUsecase) issueTokens(ctx context.Context, user *model.User) (Tokens, *model.User, error) {
	access, err := u.issue(user.ID.Hex(), user.Email, user.Role, u.accessTTL)
	if err != nil {
		return Tokens{}, nil, err
	}
	raw, err := newOpaqueToken()
	if err != nil {
		return Tokens{}, nil, err
	}
	record := &model.RefreshToken{
		UserID:    user.ID,
		TokenHash: hashToken(raw),
		ExpiresAt: time.Now().Add(u.refreshTTL),
	}
	if err := u.refresh.Create(ctx, record); err != nil {
		return Tokens{}, nil, err
	}
	return Tokens{Access: access, Refresh: raw}, user, nil
}

// newOpaqueToken returns a cryptographically random 256-bit token as hex.
func newOpaqueToken() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

// hashToken returns the SHA-256 hex of a token; only the hash is ever stored.
func hashToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}
