package model

import (
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
)

type Product struct {
	ID          bson.ObjectID `bson:"_id,omitempty" json:"id"`
	SellerID    bson.ObjectID `bson:"seller_id" json:"seller_id"`
	SellerName  string        `bson:"seller_name" json:"seller_name"`
	Name        string        `bson:"name" json:"name"`
	Description string        `bson:"description" json:"description"`
	Price       float64       `bson:"price" json:"price"`
	Stock       int           `bson:"stock" json:"stock"`
	Category    string        `bson:"category" json:"category"`
	Images      []string      `bson:"images" json:"images"`
	CreatedAt   time.Time     `bson:"created_at" json:"created_at"`
	UpdatedAt   time.Time     `bson:"updated_at" json:"updated_at"`
}

type ProductRequest struct {
	Name        string   `json:"name"`
	Description string   `json:"description"`
	Price       float64  `json:"price"`
	Stock       int      `json:"stock"`
	Category    string   `json:"category"`
	Images      []string `json:"images"`
}
