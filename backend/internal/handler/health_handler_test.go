package handler

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestHealthLiveIsAlwaysOK(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewHealthHandler(func(context.Context) error { return nil })
	r := gin.New()
	r.GET("/healthz", h.Live)

	w := httptest.NewRecorder()
	r.ServeHTTP(w, httptest.NewRequest(http.MethodGet, "/healthz", nil))
	if w.Code != http.StatusOK {
		t.Fatalf("expected liveness 200, got %d", w.Code)
	}
}

func TestHealthReadyReflectsDependencyState(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.GET("/ready-ok", NewHealthHandler(func(context.Context) error { return nil }).Ready)
	r.GET("/ready-bad", NewHealthHandler(func(context.Context) error { return errors.New("db down") }).Ready)

	ok := httptest.NewRecorder()
	r.ServeHTTP(ok, httptest.NewRequest(http.MethodGet, "/ready-ok", nil))
	if ok.Code != http.StatusOK {
		t.Fatalf("expected readiness 200 when the dependency is healthy, got %d", ok.Code)
	}

	bad := httptest.NewRecorder()
	r.ServeHTTP(bad, httptest.NewRequest(http.MethodGet, "/ready-bad", nil))
	if bad.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected readiness 503 when the dependency is down, got %d", bad.Code)
	}
}
