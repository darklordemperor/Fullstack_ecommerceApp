package model

import (
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
)

type User struct {
	ID             bson.ObjectID `bson:"_id,omitempty" json:"id"`
	Name           string        `bson:"name" json:"name"`
	Lastname       string        `bson:"lastname" json:"lastname"`
	Age            int           `bson:"age" json:"age"`
	Gender         string        `bson:"gender,omitempty" json:"gender,omitempty"`
	Email          string        `bson:"email" json:"email"`
	Password       string        `bson:"password" json:"-"`
	Role           []string      `bson:"role" json:"role"`
	Banned         bool          `bson:"banned" json:"banned"`
	Address        string        `bson:"address,omitempty" json:"address,omitempty"`
	ProfileImage   string        `bson:"profile_image,omitempty" json:"profile_image,omitempty"`
	ShopName       string        `bson:"shop_name,omitempty" json:"shop_name,omitempty"`
	ShopLocation   string        `bson:"shop_location,omitempty" json:"shop_location,omitempty"`
	TaxPayerNumber string        `bson:"tax_payer_number,omitempty" json:"tax_payer_number,omitempty"`
	SellerStatus   string        `bson:"seller_status,omitempty" json:"seller_status,omitempty"`
	CreatedAt      time.Time     `bson:"created_at" json:"created_at"`
}

type RegisterRequest struct {
	Name            string `json:"name"`
	Lastname        string `json:"lastname"`
	Age             int    `json:"age"`
	Gender          string `json:"gender"`
	Email           string `json:"email"`
	Address         string `json:"address"`
	ProfileImage    string `json:"profile_image"`
	Password        string `json:"password"`
	ConfirmPassword string `json:"confirm_password"`
}

type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type UpdateProfileRequest struct {
	Name         string `json:"name"`
	Lastname     string `json:"lastname"`
	Age          int    `json:"age"`
	Gender       string `json:"gender"`
	Address      string `json:"address"`
	ProfileImage string `json:"profile_image"`
}

type SellerApplyRequest struct {
	ShopName       string `json:"shop_name"`
	ShopLocation   string `json:"shop_location"`
	TaxPayerNumber string `json:"tax_payer_number"`
}
