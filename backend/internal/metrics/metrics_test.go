package metrics

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestExpositionUsesRouteTemplateNotRawPath(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(Middleware())
	r.GET("/api/products/:id", func(c *gin.Context) { c.Status(http.StatusOK) })
	r.GET("/metrics", Handler())

	// Record one observation against a parameterized route.
	r.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(http.MethodGet, "/api/products/42", nil))

	// Scrape.
	w := httptest.NewRecorder()
	r.ServeHTTP(w, httptest.NewRequest(http.MethodGet, "/metrics", nil))

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 from /metrics, got %d", w.Code)
	}
	body := w.Body.String()

	if !strings.Contains(body, `route="/api/products/:id"`) {
		t.Fatalf("expected the route template label, got:\n%s", body)
	}
	if strings.Contains(body, `route="/api/products/42"`) {
		t.Fatalf("raw id leaked into a label — this is a cardinality bug:\n%s", body)
	}
	for _, want := range []string{
		"http_requests_total{",
		"http_request_duration_seconds_bucket{",
		"http_request_duration_seconds_count{",
		"http_requests_in_flight",
	} {
		if !strings.Contains(body, want) {
			t.Fatalf("expected %q in the exposition output, got:\n%s", want, body)
		}
	}
}
