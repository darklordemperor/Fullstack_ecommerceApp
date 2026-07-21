package middleware

import (
	"net/http"
	"runtime/debug"
	"time"

	"ecommerce/backend/internal/observability"
	"github.com/gin-gonic/gin"
)

// RequestIDHeader is the header used to receive and echo the correlation id.
const RequestIDHeader = "X-Request-ID"

// RequestID assigns a correlation id to every request. An inbound
// X-Request-ID is honoured (so a trace started at the gateway or load balancer
// is preserved end to end); otherwise a fresh id is generated. The id is put
// on the request context (for the logger and handlers) and echoed in the
// response header so a client can quote it in a bug report.
func RequestID() gin.HandlerFunc {
	return func(c *gin.Context) {
		id := c.GetHeader(RequestIDHeader)
		if id == "" {
			id = observability.NewRequestID()
		}
		c.Request = c.Request.WithContext(observability.WithRequestID(c.Request.Context(), id))
		c.Set("request_id", id)
		c.Header(RequestIDHeader, id)
		c.Next()
	}
}

// RequestLogger emits exactly one structured line per request once it
// completes: error level for 5xx, warn for 4xx, info otherwise — so alerts can
// key off level alone. Request bodies are never logged (avoids leaking
// passwords or tokens).
func RequestLogger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		c.Next()

		status := c.Writer.Status()
		attrs := []any{
			"method", c.Request.Method,
			"path", path,
			"route", c.FullPath(),
			"status", status,
			"latency_ms", time.Since(start).Milliseconds(),
			"client_ip", c.ClientIP(),
			"bytes", c.Writer.Size(),
		}
		if len(c.Errors) > 0 {
			attrs = append(attrs, "errors", c.Errors.String())
		}

		logger := observability.Logger(c.Request.Context())
		switch {
		case status >= http.StatusInternalServerError:
			logger.Error("http_request", attrs...)
		case status >= http.StatusBadRequest:
			logger.Warn("http_request", attrs...)
		default:
			logger.Info("http_request", attrs...)
		}
	}
}

// Recovery turns a panic into a structured error log (with stack trace and the
// request id) plus a clean 500 that carries the correlation id — instead of
// leaking a stack trace to the client or dying silently.
func Recovery() gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if r := recover(); r != nil {
				observability.Logger(c.Request.Context()).Error("panic_recovered",
					"panic", r,
					"path", c.Request.URL.Path,
					"stack", string(debug.Stack()),
				)
				if !c.Writer.Written() {
					c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{
						"error":      "internal server error",
						"code":       "internal_error",
						"request_id": c.GetString("request_id"),
					})
				}
			}
		}()
		c.Next()
	}
}
