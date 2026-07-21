// Package observability centralizes structured logging and request correlation.
//
// Every log line is emitted as a single JSON object so a log aggregator
// (Loki, CloudWatch, Datadog, ...) can index and query by field instead of
// grepping free text. A per-request correlation id is threaded through the
// context so that, given one failing request, every line it produced can be
// pulled up together — the opposite of a "blind search".
package observability

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"log/slog"
	"os"
)

type ctxKey int

const requestIDKey ctxKey = iota

// Setup installs a process-wide JSON logger at the given level and returns it.
// Call this before anything else in main so all later logs are structured.
func Setup(level slog.Level) *slog.Logger {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: level}))
	slog.SetDefault(logger)
	return logger
}

// NewRequestID returns a random 128-bit hex correlation id.
func NewRequestID() string {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		// crypto/rand essentially never fails; degrade instead of panicking.
		return "req-unknown"
	}
	return hex.EncodeToString(b)
}

// WithRequestID stores the correlation id on the context.
func WithRequestID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, requestIDKey, id)
}

// RequestID reads the correlation id from the context ("" if absent).
func RequestID(ctx context.Context) string {
	if id, ok := ctx.Value(requestIDKey).(string); ok {
		return id
	}
	return ""
}

// Logger returns the default logger pre-tagged with the context's request id,
// so every line written during a request carries the same correlation key.
func Logger(ctx context.Context) *slog.Logger {
	if id := RequestID(ctx); id != "" {
		return slog.Default().With("request_id", id)
	}
	return slog.Default()
}
