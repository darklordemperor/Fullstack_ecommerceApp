// Package httpx centralizes the HTTP error envelope so every endpoint fails the
// same way.
//
// The `error` field stays a top-level value for backward compatibility with the
// existing Flutter client (which reads `data['error']`). Two fields are added:
//   - `code`: a stable machine-readable identifier so the client and log-based
//     alerting can branch on it instead of parsing human-facing message text.
//   - `request_id`: the correlation id, so a user-reported failure maps directly
//     to its server-side log lines.
package httpx

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// Stable, machine-readable error codes.
const (
	CodeBadRequest   = "bad_request"
	CodeUnauthorized = "unauthorized"
	CodeForbidden    = "forbidden"
	CodeNotFound     = "not_found"
	CodeConflict     = "conflict"
	CodeValidation   = "validation_error"
	CodeInternal     = "internal_error"
	CodeRateLimited  = "rate_limited"
)

// Error writes a consistent single-message error response.
func Error(c *gin.Context, status int, code, message string) {
	c.JSON(status, gin.H{
		"error":      message,
		"code":       code,
		"request_id": c.GetString("request_id"),
	})
}

// ValidationError preserves the field -> message map shape the register form
// consumes, augmented with a code and correlation id.
func ValidationError(c *gin.Context, fields map[string]string) {
	c.JSON(http.StatusBadRequest, gin.H{
		"error":      fields,
		"code":       CodeValidation,
		"request_id": c.GetString("request_id"),
	})
}
