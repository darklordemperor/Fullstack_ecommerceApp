package middleware

import (
	"net/http"
	"sync"
	"time"

	"ecommerce/backend/internal/httpx"
	"github.com/gin-gonic/gin"
)

// RateLimiter is a per-client-IP token-bucket limiter. It bounds abuse (brute
// force, scraping, accidental request storms) without an external dependency.
//
// It is in-memory, so it limits traffic against a SINGLE node; behind a load
// balancer each node keeps its own buckets. For a limit shared across the whole
// fleet, back this with Redis — the middleware seam stays the same.
type RateLimiter struct {
	mu      sync.Mutex
	buckets map[string]*tokenBucket
	rate    float64 // tokens refilled per second
	burst   float64 // bucket capacity
}

type tokenBucket struct {
	tokens   float64
	lastSeen time.Time
}

// NewRateLimiter allows `rate` requests/sec per client with a burst of `burst`,
// and starts a background sweeper that evicts idle buckets so memory stays
// bounded under churn.
func NewRateLimiter(rate, burst float64) *RateLimiter {
	rl := &RateLimiter{buckets: make(map[string]*tokenBucket), rate: rate, burst: burst}
	go rl.sweep()
	return rl
}

// Middleware rejects requests over the limit with 429 and a Retry-After hint.
func (rl *RateLimiter) Middleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		if !rl.allow(c.ClientIP()) {
			c.Header("Retry-After", "1")
			httpx.Error(c, http.StatusTooManyRequests, httpx.CodeRateLimited,
				"too many requests, please slow down")
			c.Abort()
			return
		}
		c.Next()
	}
}

func (rl *RateLimiter) allow(key string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	b := rl.buckets[key]
	if b == nil {
		// First request from this client consumes one token of a full bucket.
		rl.buckets[key] = &tokenBucket{tokens: rl.burst - 1, lastSeen: now}
		return true
	}
	b.tokens = min(rl.burst, b.tokens+now.Sub(b.lastSeen).Seconds()*rl.rate)
	b.lastSeen = now
	if b.tokens < 1 {
		return false
	}
	b.tokens--
	return true
}

func (rl *RateLimiter) sweep() {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()
	for range ticker.C {
		rl.mu.Lock()
		for key, b := range rl.buckets {
			if time.Since(b.lastSeen) > 10*time.Minute {
				delete(rl.buckets, key)
			}
		}
		rl.mu.Unlock()
	}
}
