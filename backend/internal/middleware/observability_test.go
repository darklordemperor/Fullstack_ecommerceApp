package middleware

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"ecommerce/backend/internal/observability"
	"github.com/gin-gonic/gin"
)

func TestRequestIDGeneratesAndPropagates(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(RequestID())

	var ctxID string
	r.GET("/x", func(c *gin.Context) {
		ctxID = observability.RequestID(c.Request.Context())
		c.Status(http.StatusOK)
	})

	w := httptest.NewRecorder()
	r.ServeHTTP(w, httptest.NewRequest(http.MethodGet, "/x", nil))

	header := w.Header().Get(RequestIDHeader)
	if header == "" {
		t.Fatal("expected a generated request id echoed in the response header")
	}
	if ctxID != header {
		t.Fatalf("context id %q must match response header id %q", ctxID, header)
	}
}

func TestRequestIDHonoursInboundTrace(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(RequestID())
	r.GET("/x", func(c *gin.Context) { c.Status(http.StatusOK) })

	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/x", nil)
	req.Header.Set(RequestIDHeader, "trace-from-gateway")
	r.ServeHTTP(w, req)

	if got := w.Header().Get(RequestIDHeader); got != "trace-from-gateway" {
		t.Fatalf("expected inbound trace id preserved, got %q", got)
	}
}

func TestRecoveryReturnsStructured500(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(RequestID(), Recovery())
	r.GET("/boom", func(c *gin.Context) { panic("kaboom") })

	w := httptest.NewRecorder()
	r.ServeHTTP(w, httptest.NewRequest(http.MethodGet, "/boom", nil))

	if w.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500 after a panic, got %d", w.Code)
	}
	if w.Header().Get(RequestIDHeader) == "" {
		t.Fatal("expected the request id header on the recovered error")
	}
	if body := w.Body.String(); !strings.Contains(body, "request_id") || !strings.Contains(body, "internal_error") {
		t.Fatalf("expected a structured error body with request_id and code, got %s", body)
	}
}
