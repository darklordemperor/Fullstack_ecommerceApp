// Package domain holds the enterprise-wide business contracts: the entity
// persistence ports (interfaces the usecase layer depends on) and the sentinel
// business errors. It is the innermost layer — it must not import gin, HTTP, or
// any delivery concern, so business rules stay independent of how the app is
// exposed or where data is stored.
package domain

import "errors"

// Sentinel business errors. The usecase layer returns these; the delivery layer
// (HTTP handlers) maps them to status codes with errors.Is, so status decisions
// live in one place instead of being scattered as string comparisons.
var (
	ErrEmailAlreadyExists  = errors.New("email already registered")
	ErrInvalidCredentials  = errors.New("invalid email or password")
	ErrInvalidRefreshToken = errors.New("invalid or expired refresh token")
	ErrAccountBanned       = errors.New("this account has been banned")
	ErrNotFound            = errors.New("resource not found")
	ErrForbidden           = errors.New("not allowed to perform this action")

	// Product
	ErrProductNotOwned = errors.New("product not found or not owned by seller")

	// Cart / checkout
	ErrCartEmpty          = errors.New("cart is empty")
	ErrCartItemNotFound   = errors.New("cart item not found")
	ErrNoItemsSelected    = errors.New("select at least one cart item")
	ErrProductUnavailable = errors.New("one product in your cart is no longer available")
	ErrInsufficientStock  = errors.New("quantity is greater than available stock")
)
