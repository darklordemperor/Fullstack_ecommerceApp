package handler

import (
	"errors"
	"net/http"

	"ecommerce/backend/internal/domain"
	"ecommerce/backend/internal/httpx"
	"github.com/gin-gonic/gin"
)

// respondError is the single place that maps a domain (business) error to an
// HTTP status + machine code. Handlers stay free of status decisions: they just
// call this. An unrecognised error is treated as an internal fault — attached to
// the gin context so the request logger records it with the request id, but
// surfaced to the client only as a generic message that leaks no internals.
func respondError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, domain.ErrEmailAlreadyExists):
		httpx.Error(c, http.StatusConflict, httpx.CodeConflict, err.Error())
	case errors.Is(err, domain.ErrInvalidCredentials),
		errors.Is(err, domain.ErrInvalidRefreshToken):
		httpx.Error(c, http.StatusUnauthorized, httpx.CodeUnauthorized, err.Error())
	case errors.Is(err, domain.ErrAccountBanned), errors.Is(err, domain.ErrForbidden):
		httpx.Error(c, http.StatusForbidden, httpx.CodeForbidden, err.Error())
	case errors.Is(err, domain.ErrNotFound),
		errors.Is(err, domain.ErrProductNotOwned),
		errors.Is(err, domain.ErrCartItemNotFound),
		errors.Is(err, domain.ErrProductUnavailable):
		httpx.Error(c, http.StatusNotFound, httpx.CodeNotFound, err.Error())
	case errors.Is(err, domain.ErrCartEmpty),
		errors.Is(err, domain.ErrNoItemsSelected),
		errors.Is(err, domain.ErrInsufficientStock):
		httpx.Error(c, http.StatusBadRequest, httpx.CodeBadRequest, err.Error())
	default:
		_ = c.Error(err)
		httpx.Error(c, http.StatusInternalServerError, httpx.CodeInternal, "internal server error")
	}
}
