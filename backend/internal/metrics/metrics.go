// Package metrics records RED metrics (Rate, Errors, Duration) for HTTP traffic
// and exposes them in Prometheus text exposition format at /metrics.
//
// It is intentionally dependency-free (standard library only) so the build has
// no extra modules to fetch. In production you would swap this for
// prometheus/client_golang, which handles concurrency, exemplars, and native
// histograms; the exposition format emitted here is identical, so a Prometheus
// server can scrape it as-is and alerting rules would not change.
//
// All series are keyed by the route TEMPLATE (gin's c.FullPath(), e.g.
// "/api/products/:id") rather than the raw URL, so path parameters like an id
// can never explode label cardinality.
package metrics

import (
	"net/http"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

// bucketBounds are the upper bounds (seconds) for the latency histogram.
var bucketBounds = []float64{0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10}

type counterKey struct{ method, route, status string }
type routeKey struct{ method, route string }

type histData struct {
	sum     float64
	count   uint64
	buckets []uint64 // non-cumulative counts, aligned with bucketBounds
}

var (
	mu       sync.Mutex
	counters = map[counterKey]uint64{}
	hists    = map[routeKey]*histData{}
	inFlight int64
)

// Middleware records one observation per request.
func Middleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()

		mu.Lock()
		inFlight++
		mu.Unlock()

		c.Next()

		route := c.FullPath()
		if route == "" {
			route = "unmatched"
		}
		elapsed := time.Since(start).Seconds()
		status := strconv.Itoa(c.Writer.Status())

		mu.Lock()
		inFlight--
		counters[counterKey{c.Request.Method, route, status}]++
		rk := routeKey{c.Request.Method, route}
		h := hists[rk]
		if h == nil {
			h = &histData{buckets: make([]uint64, len(bucketBounds))}
			hists[rk] = h
		}
		h.sum += elapsed
		h.count++
		for i, bound := range bucketBounds {
			if elapsed <= bound {
				h.buckets[i]++
				break
			}
		}
		mu.Unlock()
	}
}

// Handler serves the current metrics in Prometheus text exposition format.
func Handler() gin.HandlerFunc {
	return func(c *gin.Context) {
		mu.Lock()
		defer mu.Unlock()

		var b strings.Builder

		b.WriteString("# HELP http_requests_total Total HTTP requests processed.\n")
		b.WriteString("# TYPE http_requests_total counter\n")
		ckeys := make([]counterKey, 0, len(counters))
		for k := range counters {
			ckeys = append(ckeys, k)
		}
		sort.Slice(ckeys, func(i, j int) bool {
			if ckeys[i].route != ckeys[j].route {
				return ckeys[i].route < ckeys[j].route
			}
			if ckeys[i].method != ckeys[j].method {
				return ckeys[i].method < ckeys[j].method
			}
			return ckeys[i].status < ckeys[j].status
		})
		for _, k := range ckeys {
			b.WriteString("http_requests_total{method=")
			writeLabel(&b, k.method)
			b.WriteString(",route=")
			writeLabel(&b, k.route)
			b.WriteString(",status=")
			writeLabel(&b, k.status)
			b.WriteString("} ")
			b.WriteString(strconv.FormatUint(counters[k], 10))
			b.WriteByte('\n')
		}

		b.WriteString("# HELP http_request_duration_seconds HTTP request latency in seconds.\n")
		b.WriteString("# TYPE http_request_duration_seconds histogram\n")
		rkeys := make([]routeKey, 0, len(hists))
		for k := range hists {
			rkeys = append(rkeys, k)
		}
		sort.Slice(rkeys, func(i, j int) bool {
			if rkeys[i].route != rkeys[j].route {
				return rkeys[i].route < rkeys[j].route
			}
			return rkeys[i].method < rkeys[j].method
		})
		for _, rk := range rkeys {
			h := hists[rk]
			var cumulative uint64
			for i, bound := range bucketBounds {
				cumulative += h.buckets[i]
				writeBucket(&b, rk, strconv.FormatFloat(bound, 'g', -1, 64), cumulative)
			}
			writeBucket(&b, rk, "+Inf", h.count)
			writeHistScalar(&b, "http_request_duration_seconds_sum", rk, strconv.FormatFloat(h.sum, 'g', -1, 64))
			writeHistScalar(&b, "http_request_duration_seconds_count", rk, strconv.FormatUint(h.count, 10))
		}

		b.WriteString("# HELP http_requests_in_flight In-flight HTTP requests.\n")
		b.WriteString("# TYPE http_requests_in_flight gauge\n")
		b.WriteString("http_requests_in_flight ")
		b.WriteString(strconv.FormatInt(inFlight, 10))
		b.WriteByte('\n')

		c.Data(http.StatusOK, "text/plain; version=0.0.4; charset=utf-8", []byte(b.String()))
	}
}

func writeBucket(b *strings.Builder, rk routeKey, le string, value uint64) {
	b.WriteString("http_request_duration_seconds_bucket{method=")
	writeLabel(b, rk.method)
	b.WriteString(",route=")
	writeLabel(b, rk.route)
	b.WriteString(",le=")
	writeLabel(b, le)
	b.WriteString("} ")
	b.WriteString(strconv.FormatUint(value, 10))
	b.WriteByte('\n')
}

func writeHistScalar(b *strings.Builder, name string, rk routeKey, value string) {
	b.WriteString(name)
	b.WriteString("{method=")
	writeLabel(b, rk.method)
	b.WriteString(",route=")
	writeLabel(b, rk.route)
	b.WriteString("} ")
	b.WriteString(value)
	b.WriteByte('\n')
}

// writeLabel writes a Prometheus-escaped, double-quoted label value.
func writeLabel(b *strings.Builder, v string) {
	b.WriteByte('"')
	for _, r := range v {
		switch r {
		case '\\':
			b.WriteString(`\\`)
		case '"':
			b.WriteString(`\"`)
		case '\n':
			b.WriteString(`\n`)
		default:
			b.WriteRune(r)
		}
	}
	b.WriteByte('"')
}
