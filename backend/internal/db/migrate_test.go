package db

import "testing"

func TestPendingMigrationsSelectsUnappliedInOrder(t *testing.T) {
	all := []Migration{{Version: 1}, {Version: 2}, {Version: 3}}
	pending := pendingMigrations(map[int]bool{1: true}, all)
	if len(pending) != 2 || pending[0].Version != 2 || pending[1].Version != 3 {
		t.Fatalf("expected versions [2,3], got %+v", pending)
	}
}

func TestPendingMigrationsSortsByVersion(t *testing.T) {
	all := []Migration{{Version: 3}, {Version: 1}, {Version: 2}}
	pending := pendingMigrations(map[int]bool{}, all)
	for i, want := range []int{1, 2, 3} {
		if pending[i].Version != want {
			t.Fatalf("expected ascending versions, got %+v", pending)
		}
	}
}

func TestPendingMigrationsEmptyWhenAllApplied(t *testing.T) {
	all := []Migration{{Version: 1}, {Version: 2}}
	if pending := pendingMigrations(map[int]bool{1: true, 2: true}, all); len(pending) != 0 {
		t.Fatalf("expected no pending migrations, got %+v", pending)
	}
}

func TestRegisteredMigrationsAreUniqueAndOrdered(t *testing.T) {
	seen := map[int]bool{}
	last := 0
	for _, m := range migrations {
		if seen[m.Version] {
			t.Fatalf("duplicate migration version %d", m.Version)
		}
		if m.Version <= last {
			t.Fatalf("migrations must be strictly ascending; %d after %d", m.Version, last)
		}
		if m.Up == nil {
			t.Fatalf("migration %d has no Up function", m.Version)
		}
		seen[m.Version] = true
		last = m.Version
	}
}
