package model

import (
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
)

// RefreshToken is the server-side record of an issued refresh token. Only the
// SHA-256 hash of the token is persisted, so a database leak never exposes a
// usable token. Rotation flips Revoked on the old record each time it is
// exchanged, which also lets us detect reuse of a stolen token.
type RefreshToken struct {
	ID        bson.ObjectID `bson:"_id,omitempty" json:"-"`
	UserID    bson.ObjectID `bson:"user_id" json:"-"`
	TokenHash string        `bson:"token_hash" json:"-"`
	ExpiresAt time.Time     `bson:"expires_at" json:"-"`
	Revoked   bool          `bson:"revoked" json:"-"`
	CreatedAt time.Time     `bson:"created_at" json:"-"`
}
