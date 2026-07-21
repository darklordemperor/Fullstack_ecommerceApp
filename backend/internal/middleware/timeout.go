package middleware

import (
	"context"
	"time"

	"github.com/gin-gonic/gin"
)

// Timeout bounds how long downstream work may run by attaching a deadline to
// the request context. Every MongoDB call in this codebase takes that context,
// so when the deadline passes the driver aborts the in-flight query and the
// handler surfaces the error instead of a goroutine blocking forever on a slow
// database. Bounding per-request work is a prerequisite for running safely
// behind a load balancer: one slow dependency can no longer exhaust a node.
//
// Note: this cancels downstream work; it does not forcibly write a response if
// a handler ignores the context. A hard response deadline would wrap the engine
// in http.TimeoutHandler (or gin-contrib/timeout).
func Timeout(d time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(c.Request.Context(), d)
		defer cancel()
		c.Request = c.Request.WithContext(ctx)
		c.Next()
	}
}
