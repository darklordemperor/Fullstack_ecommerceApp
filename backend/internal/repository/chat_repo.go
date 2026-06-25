package repository

import (
	"context"
	"errors"
	"time"

	"ecommerce/backend/internal/model"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

type ChatRepository struct {
	conversations *mongo.Collection
	messages      *mongo.Collection
}

func NewChatRepository(db *mongo.Database) *ChatRepository {
	return &ChatRepository{
		conversations: db.Collection("conversations"),
		messages:      db.Collection("chat_messages"),
	}
}

func (r *ChatRepository) ListConversations(ctx context.Context, userID bson.ObjectID) ([]model.Conversation, error) {
	filter := bson.M{"$or": []bson.M{{"buyer_id": userID}, {"seller_id": userID}}}
	cursor, err := r.conversations.Find(ctx, filter, options.Find().SetSort(bson.D{{Key: "updated_at", Value: -1}}))
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	var conversations []model.Conversation
	if err := cursor.All(ctx, &conversations); err != nil {
		return nil, err
	}
	if conversations == nil {
		conversations = []model.Conversation{}
	}
	return conversations, nil
}

func (r *ChatRepository) FindConversationForUser(ctx context.Context, id, userID bson.ObjectID) (*model.Conversation, error) {
	var conversation model.Conversation
	err := r.conversations.FindOne(ctx, bson.M{
		"_id": id,
		"$or": []bson.M{
			{"buyer_id": userID},
			{"seller_id": userID},
		},
	}).Decode(&conversation)
	if errors.Is(err, mongo.ErrNoDocuments) {
		return nil, nil
	}
	return &conversation, err
}

func (r *ChatRepository) StartConversation(ctx context.Context, conversation *model.Conversation) (*model.Conversation, error) {
	now := time.Now()
	conversation.ID = bson.NewObjectID()
	conversation.CreatedAt = now
	conversation.UpdatedAt = now

	filter := bson.M{
		"buyer_id":   conversation.BuyerID,
		"seller_id":  conversation.SellerID,
		"product_id": conversation.ProductID,
	}
	update := bson.M{"$setOnInsert": conversation}
	opts := options.FindOneAndUpdate().SetUpsert(true).SetReturnDocument(options.After)

	var saved model.Conversation
	if err := r.conversations.FindOneAndUpdate(ctx, filter, update, opts).Decode(&saved); err != nil {
		return nil, err
	}
	return &saved, nil
}

func (r *ChatRepository) ListMessages(ctx context.Context, conversationID bson.ObjectID) ([]model.ChatMessage, error) {
	cursor, err := r.messages.Find(ctx, bson.M{"conversation_id": conversationID}, options.Find().SetSort(bson.D{{Key: "created_at", Value: 1}}))
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	var messages []model.ChatMessage
	if err := cursor.All(ctx, &messages); err != nil {
		return nil, err
	}
	if messages == nil {
		messages = []model.ChatMessage{}
	}
	return messages, nil
}

func (r *ChatRepository) SendMessage(ctx context.Context, conversation model.Conversation, senderID bson.ObjectID, senderName, text, image, messageType string) (*model.ChatMessage, error) {
	now := time.Now()
	message := &model.ChatMessage{
		ID:             bson.NewObjectID(),
		ConversationID: conversation.ID,
		SenderID:       senderID,
		SenderName:     senderName,
		Text:           text,
		Image:          image,
		MessageType:    messageType,
		CreatedAt:      now,
		ExpiresAt:      now.AddDate(2, 0, 0),
	}
	if _, err := r.messages.InsertOne(ctx, message); err != nil {
		return nil, err
	}

	preview := text
	if messageType == model.MessageTypeImage {
		preview = "Sent an image"
	}
	inc := bson.M{}
	if senderID == conversation.BuyerID {
		inc["seller_unread_count"] = 1
	} else {
		inc["buyer_unread_count"] = 1
	}
	_, err := r.conversations.UpdateOne(ctx, bson.M{"_id": conversation.ID}, bson.M{
		"$set": bson.M{
			"last_message":      preview,
			"last_message_type": messageType,
			"last_sender_id":    senderID,
			"updated_at":        now,
		},
		"$inc": inc,
	})
	return message, err
}

func (r *ChatRepository) MarkRead(ctx context.Context, conversation model.Conversation, userID bson.ObjectID) error {
	field := "buyer_unread_count"
	if userID == conversation.SellerID {
		field = "seller_unread_count"
	}
	_, err := r.conversations.UpdateOne(ctx, bson.M{"_id": conversation.ID}, bson.M{
		"$set": bson.M{field: 0},
	})
	return err
}
