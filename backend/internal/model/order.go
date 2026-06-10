package model

import (
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
)

type Order struct {
	ID           bson.ObjectID `bson:"_id,omitempty" json:"id"`
	CustomerID   bson.ObjectID `bson:"customer_id" json:"customer_id"`
	CustomerName string        `bson:"customer_name" json:"customer_name"`
	SellerID     bson.ObjectID `bson:"seller_id" json:"seller_id"`
	Items        []CartItem    `bson:"items" json:"items"`
	Total        float64       `bson:"total" json:"total"`
	Status       string        `bson:"status" json:"status"`
	CreatedAt    time.Time     `bson:"created_at" json:"created_at"`
}
