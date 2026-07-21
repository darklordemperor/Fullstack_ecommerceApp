# syntax=docker/dockerfile:1

# ---- build stage ----
FROM golang:1.24-alpine AS builder
WORKDIR /app
# Download modules in their own layer so source edits don't re-fetch deps.
COPY go.mod go.sum ./
RUN go mod download
COPY . .
# Static, stripped binary: CGO off so it needs no libc at runtime; -trimpath
# for reproducible paths; -s -w to drop the debug/symbol tables.
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /app/server ./cmd

# ---- runtime stage ----
FROM alpine:3.20
# ca-certificates lets the app dial TLS (e.g. MongoDB Atlas). Run as a
# non-root, no-home user to shrink the blast radius of a compromise.
RUN apk add --no-cache ca-certificates \
    && adduser -D -H -u 10001 appuser
WORKDIR /app
COPY --from=builder /app/server /app/server
USER appuser
EXPOSE 8080
# Container-level liveness so an orchestrator can restart a wedged process.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -qO- http://127.0.0.1:8080/healthz >/dev/null 2>&1 || exit 1
CMD ["/app/server"]
