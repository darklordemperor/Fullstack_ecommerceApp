package usecase

import (
	"context"
	"errors"
	"testing"
	"time"

	"ecommerce/backend/internal/domain"
	"ecommerce/backend/internal/model"
	"go.mongodb.org/mongo-driver/v2/bson"
	"golang.org/x/crypto/bcrypt"
)

// The whole point of the usecase layer: business rules are tested here with
// fake repositories and a stub token issuer — no gin, no MongoDB, no network.

func newAuthUsecase(users domain.UserRepository, refresh domain.RefreshTokenRepository) *AuthUsecase {
	return NewAuthUsecase(users, refresh, stubIssuer, 15*time.Minute, 24*time.Hour)
}

func TestRegisterRejectsDuplicateEmail(t *testing.T) {
	repo := &fakeUserRepo{existing: &model.User{Email: "taken@example.com"}}
	uc := newAuthUsecase(repo, newFakeRefreshRepo())

	_, err := uc.Register(context.Background(), model.RegisterRequest{Email: "taken@example.com", Password: "abc12345"})
	if !errors.Is(err, domain.ErrEmailAlreadyExists) {
		t.Fatalf("expected ErrEmailAlreadyExists, got %v", err)
	}
	if repo.created != nil {
		t.Fatal("no user should be created when the email is taken")
	}
}

func TestRegisterHashesPasswordAndDefaultsToCustomer(t *testing.T) {
	repo := &fakeUserRepo{}
	uc := newAuthUsecase(repo, newFakeRefreshRepo())

	user, err := uc.Register(context.Background(), model.RegisterRequest{
		Email: "New@Example.com ", Password: "abc12345", Name: " Ada ",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if user.Email != "new@example.com" {
		t.Fatalf("email should be normalized, got %q", user.Email)
	}
	if user.Name != "Ada" {
		t.Fatalf("name should be trimmed, got %q", user.Name)
	}
	if len(user.Role) != 1 || user.Role[0] != "customer" {
		t.Fatalf("expected default customer role, got %v", user.Role)
	}
	if bcrypt.CompareHashAndPassword([]byte(user.Password), []byte("abc12345")) != nil {
		t.Fatal("stored password should be a bcrypt hash of the input")
	}
}

func TestLoginRejectsWrongPassword(t *testing.T) {
	hash, _ := bcrypt.GenerateFromPassword([]byte("correct-password"), bcrypt.DefaultCost)
	repo := &fakeUserRepo{existing: &model.User{ID: bson.NewObjectID(), Email: "a@b.com", Password: string(hash)}}
	uc := newAuthUsecase(repo, newFakeRefreshRepo())

	_, _, err := uc.Login(context.Background(), "a@b.com", "wrong-password")
	if !errors.Is(err, domain.ErrInvalidCredentials) {
		t.Fatalf("expected ErrInvalidCredentials, got %v", err)
	}
}

func TestLoginRejectsBannedAccount(t *testing.T) {
	hash, _ := bcrypt.GenerateFromPassword([]byte("abc12345"), bcrypt.DefaultCost)
	repo := &fakeUserRepo{existing: &model.User{ID: bson.NewObjectID(), Email: "a@b.com", Password: string(hash), Banned: true}}
	uc := newAuthUsecase(repo, newFakeRefreshRepo())

	_, _, err := uc.Login(context.Background(), "a@b.com", "abc12345")
	if !errors.Is(err, domain.ErrAccountBanned) {
		t.Fatalf("expected ErrAccountBanned, got %v", err)
	}
}

func TestLoginIssuesAccessAndRefreshTokens(t *testing.T) {
	hash, _ := bcrypt.GenerateFromPassword([]byte("abc12345"), bcrypt.DefaultCost)
	repo := &fakeUserRepo{existing: &model.User{ID: bson.NewObjectID(), Email: "a@b.com", Password: string(hash), Role: []string{"customer"}}}
	uc := newAuthUsecase(repo, newFakeRefreshRepo())

	tokens, user, err := uc.Login(context.Background(), "a@b.com", "abc12345")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if tokens.Access != "signed-token" {
		t.Fatalf("expected issued access token, got %q", tokens.Access)
	}
	if tokens.Refresh == "" {
		t.Fatal("expected a refresh token to be issued")
	}
	if user == nil || user.Email != "a@b.com" {
		t.Fatalf("expected the authenticated user, got %v", user)
	}
}

func TestRefreshRotatesTokenAndDetectsReuse(t *testing.T) {
	hash, _ := bcrypt.GenerateFromPassword([]byte("abc12345"), bcrypt.DefaultCost)
	repo := &fakeUserRepo{existing: &model.User{ID: bson.NewObjectID(), Email: "a@b.com", Password: string(hash), Role: []string{"customer"}}}
	refresh := newFakeRefreshRepo()
	uc := newAuthUsecase(repo, refresh)

	tokens, _, err := uc.Login(context.Background(), "a@b.com", "abc12345")
	if err != nil {
		t.Fatalf("login failed: %v", err)
	}

	rotated, _, err := uc.Refresh(context.Background(), tokens.Refresh)
	if err != nil {
		t.Fatalf("refresh failed: %v", err)
	}
	if rotated.Refresh == tokens.Refresh {
		t.Fatal("refresh must rotate the refresh token")
	}

	// Reusing the now-revoked original token is treated as theft.
	_, _, err = uc.Refresh(context.Background(), tokens.Refresh)
	if !errors.Is(err, domain.ErrInvalidRefreshToken) {
		t.Fatalf("expected ErrInvalidRefreshToken on reuse, got %v", err)
	}
	if !refresh.revokeAllCalled {
		t.Fatal("reuse of a revoked token must revoke the whole family")
	}
}

func TestRefreshRejectsExpiredToken(t *testing.T) {
	hash, _ := bcrypt.GenerateFromPassword([]byte("abc12345"), bcrypt.DefaultCost)
	repo := &fakeUserRepo{existing: &model.User{ID: bson.NewObjectID(), Email: "a@b.com", Password: string(hash), Role: []string{"customer"}}}
	// Negative refresh TTL makes the issued token already expired.
	uc := NewAuthUsecase(repo, newFakeRefreshRepo(), stubIssuer, 15*time.Minute, -time.Hour)

	tokens, _, _ := uc.Login(context.Background(), "a@b.com", "abc12345")
	_, _, err := uc.Refresh(context.Background(), tokens.Refresh)
	if !errors.Is(err, domain.ErrInvalidRefreshToken) {
		t.Fatalf("expected ErrInvalidRefreshToken for expired token, got %v", err)
	}
}

func TestLogoutRevokesRefreshToken(t *testing.T) {
	hash, _ := bcrypt.GenerateFromPassword([]byte("abc12345"), bcrypt.DefaultCost)
	repo := &fakeUserRepo{existing: &model.User{ID: bson.NewObjectID(), Email: "a@b.com", Password: string(hash), Role: []string{"customer"}}}
	uc := newAuthUsecase(repo, newFakeRefreshRepo())

	tokens, _, _ := uc.Login(context.Background(), "a@b.com", "abc12345")
	if err := uc.Logout(context.Background(), tokens.Refresh); err != nil {
		t.Fatalf("logout failed: %v", err)
	}
	if _, _, err := uc.Refresh(context.Background(), tokens.Refresh); !errors.Is(err, domain.ErrInvalidRefreshToken) {
		t.Fatalf("a logged-out token must not refresh, got %v", err)
	}
}

func stubIssuer(userID, email string, role []string, ttl time.Duration) (string, error) {
	return "signed-token", nil
}

// fakeUserRepo is an in-memory domain.UserRepository for usecase tests.
type fakeUserRepo struct {
	existing *model.User
	created  *model.User
}

func (f *fakeUserRepo) Create(_ context.Context, user *model.User) error {
	f.created = user
	return nil
}

func (f *fakeUserRepo) FindByEmail(_ context.Context, _ string) (*model.User, error) {
	return f.existing, nil
}

func (f *fakeUserRepo) FindByID(_ context.Context, _ bson.ObjectID) (*model.User, error) {
	return f.existing, nil
}

func (f *fakeUserRepo) FindAll(_ context.Context) ([]model.User, error) { return nil, nil }

func (f *fakeUserRepo) SetBanned(_ context.Context, _ bson.ObjectID, _ bool) error { return nil }

func (f *fakeUserRepo) UpdateProfile(_ context.Context, _ bson.ObjectID, _ model.UpdateProfileRequest) error {
	return nil
}

func (f *fakeUserRepo) ApplySeller(_ context.Context, _ bson.ObjectID, _ model.SellerApplyRequest) error {
	return nil
}

func (f *fakeUserRepo) ApproveSeller(_ context.Context, _ bson.ObjectID) error { return nil }

// fakeRefreshRepo is an in-memory domain.RefreshTokenRepository keyed by hash.
type fakeRefreshRepo struct {
	tokens          map[string]*model.RefreshToken
	revokeAllCalled bool
}

func newFakeRefreshRepo() *fakeRefreshRepo {
	return &fakeRefreshRepo{tokens: map[string]*model.RefreshToken{}}
}

func (f *fakeRefreshRepo) Create(_ context.Context, token *model.RefreshToken) error {
	if token.ID.IsZero() {
		token.ID = bson.NewObjectID()
	}
	f.tokens[token.TokenHash] = token
	return nil
}

func (f *fakeRefreshRepo) FindByHash(_ context.Context, hash string) (*model.RefreshToken, error) {
	return f.tokens[hash], nil
}

func (f *fakeRefreshRepo) Revoke(_ context.Context, id bson.ObjectID) error {
	for _, t := range f.tokens {
		if t.ID == id {
			t.Revoked = true
		}
	}
	return nil
}

func (f *fakeRefreshRepo) RevokeAllForUser(_ context.Context, userID bson.ObjectID) error {
	f.revokeAllCalled = true
	for _, t := range f.tokens {
		if t.UserID == userID {
			t.Revoked = true
		}
	}
	return nil
}
