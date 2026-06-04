package model

import (
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
)

type Cart struct {
	ID        bson.ObjectID `bson:"_id,omitempty" json:"id"`
	UserID    bson.ObjectID `bson:"user_id" json:"user_id"`
	Items     []CartItem    `bson:"items" json:"items"`
	UpdatedAt time.Time     `bson:"updated_at" json:"updated_at"`
}

type CartItem struct {
	ProductID bson.ObjectID `bson:"product_id" json:"product_id"`
	Name      string        `bson:"name" json:"name"`
	Price     float64       `bson:"price" json:"price"`
	Image     string        `bson:"image" json:"image"`
	Quantity  int           `bson:"quantity" json:"quantity"`
}

type CartQuantityRequest struct {
	ProductID string `json:"product_id"`
	Quantity  int    `json:"quantity"`
}
