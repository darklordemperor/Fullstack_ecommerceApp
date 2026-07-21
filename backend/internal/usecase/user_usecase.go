package usecase

import (
	"context"
	"strings"

	"ecommerce/backend/internal/domain"
	"ecommerce/backend/internal/model"
	"go.mongodb.org/mongo-driver/v2/bson"
)

// UserUsecase holds profile and seller-application business rules.
type UserUsecase struct {
	users domain.UserRepository
}

func NewUserUsecase(users domain.UserRepository) *UserUsecase {
	return &UserUsecase{users: users}
}

// Profile returns the current user's profile or domain.ErrNotFound.
func (u *UserUsecase) Profile(ctx context.Context, id bson.ObjectID) (*model.User, error) {
	user, err := u.users.FindByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, domain.ErrNotFound
	}
	return user, nil
}

// UpdateProfile normalizes and persists profile fields, then returns the fresh
// record so the caller always reflects stored state.
func (u *UserUsecase) UpdateProfile(ctx context.Context, id bson.ObjectID, req model.UpdateProfileRequest) (*model.User, error) {
	req.Name = strings.TrimSpace(req.Name)
	req.Lastname = strings.TrimSpace(req.Lastname)
	req.Gender = strings.TrimSpace(req.Gender)
	req.Address = strings.TrimSpace(req.Address)
	req.ProfileImage = strings.TrimSpace(req.ProfileImage)
	if err := u.users.UpdateProfile(ctx, id, req); err != nil {
		return nil, err
	}
	return u.Profile(ctx, id)
}

// ApplySeller records a seller application (status becomes "pending").
func (u *UserUsecase) ApplySeller(ctx context.Context, id bson.ObjectID, req model.SellerApplyRequest) error {
	return u.users.ApplySeller(ctx, id, req)
}

// ApproveSeller grants the seller role and marks the account approved.
func (u *UserUsecase) ApproveSeller(ctx context.Context, id bson.ObjectID) error {
	return u.users.ApproveSeller(ctx, id)
}
