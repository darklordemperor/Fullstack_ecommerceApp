package model

import (
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
)

const (
	MessageTypeText  = "text"
	MessageTypeImage = "image"
)

type Conversation struct {
	ID                bson.ObjectID `bson:"_id,omitempty" json:"id"`
	BuyerID           bson.ObjectID `bson:"buyer_id" json:"buyer_id"`
	SellerID          bson.ObjectID `bson:"seller_id" json:"seller_id"`
	ProductID         bson.ObjectID `bson:"product_id" json:"product_id"`
	ProductName       string        `bson:"product_name" json:"product_name"`
	ProductImage      string        `bson:"product_image" json:"product_image"`
	SellerName        string        `bson:"seller_name" json:"seller_name"`
	BuyerName         string        `bson:"buyer_name" json:"buyer_name"`
	LastMessage       string        `bson:"last_message" json:"last_message"`
	LastMessageType   string        `bson:"last_message_type" json:"last_message_type"`
	LastSenderID      bson.ObjectID `bson:"last_sender_id,omitempty" json:"last_sender_id,omitempty"`
	BuyerUnreadCount  int           `bson:"buyer_unread_count" json:"buyer_unread_count"`
	SellerUnreadCount int           `bson:"seller_unread_count" json:"seller_unread_count"`
	CreatedAt         time.Time     `bson:"created_at" json:"created_at"`
	UpdatedAt         time.Time     `bson:"updated_at" json:"updated_at"`
}

type ChatMessage struct {
	ID             bson.ObjectID `bson:"_id,omitempty" json:"id"`
	ConversationID bson.ObjectID `bson:"conversation_id" json:"conversation_id"`
	SenderID       bson.ObjectID `bson:"sender_id" json:"sender_id"`
	SenderName     string        `bson:"sender_name" json:"sender_name"`
	Text           string        `bson:"text" json:"text"`
	Image          string        `bson:"image" json:"image"`
	MessageType    string        `bson:"message_type" json:"message_type"`
	CreatedAt      time.Time     `bson:"created_at" json:"created_at"`
	ExpiresAt      time.Time     `bson:"expires_at" json:"expires_at"`
}

type StartChatRequest struct {
	ProductID string `json:"product_id"`
}

type SendChatMessageRequest struct {
	Text  string `json:"text"`
	Image string `json:"image"`
}
