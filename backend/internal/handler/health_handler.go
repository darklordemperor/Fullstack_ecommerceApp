package handler

import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

// HealthHandler exposes liveness and readiness probes.
//
//   - Liveness ("is the process up?") lets an orchestrator restart a hung node.
//   - Readiness ("can it serve traffic right now?") pings the database, so a
//     load balancer / Kubernetes can pull a node out of rotation when its
//     dependencies are down instead of routing users into a broken backend.
type HealthHandler struct {
	ping func(ctx context.Context) error
}

// NewHealthHandler wires the readiness check to a dependency ping (MongoDB).
func NewHealthHandler(ping func(ctx context.Context) error) *HealthHandler {
	return &HealthHandler{ping: ping}
}

// Live reports process liveness without touching dependencies.
func (h *HealthHandler) Live(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}

// Ready reports whether the service can serve traffic, verifying MongoDB is
// reachable within a short deadline.
func (h *HealthHandler) Ready(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), 2*time.Second)
	defer cancel()
	if err := h.ping(ctx); err != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{
			"status":     "unavailable",
			"dependency": "mongodb",
			"request_id": c.GetString("request_id"),
		})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": "ready"})
}
