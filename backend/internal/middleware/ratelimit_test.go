package middleware

import "testing"

func TestRateLimiterAllowsBurstThenBlocks(t *testing.T) {
	rl := NewRateLimiter(1, 3) // 1 req/s, burst of 3
	const ip = "203.0.113.7"

	allowed := 0
	for i := 0; i < 5; i++ {
		if rl.allow(ip) {
			allowed++
		}
	}
	if allowed != 3 {
		t.Fatalf("expected 3 requests allowed within the burst, got %d", allowed)
	}
}

func TestRateLimiterIsolatesClients(t *testing.T) {
	rl := NewRateLimiter(1, 1)
	if !rl.allow("client-a") {
		t.Fatal("first request from client-a should pass")
	}
	if !rl.allow("client-b") {
		t.Fatal("client-b must have its own independent bucket")
	}
	if rl.allow("client-a") {
		t.Fatal("client-a's second immediate request should be blocked")
	}
}
