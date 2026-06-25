package handler

import (
	"net/http"
	"strings"

	"ecommerce/backend/internal/model"
	"ecommerce/backend/internal/repository"
	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/v2/bson"
)

const (
	maxChatTextLength  = 2000
	maxChatImageLength = 1400000
)

type ChatHandler struct {
	chats    *repository.ChatRepository
	products *repository.ProductRepository
	users    *repository.UserRepository
}

func NewChatHandler(chats *repository.ChatRepository, products *repository.ProductRepository, users *repository.UserRepository) *ChatHandler {
	return &ChatHandler{chats: chats, products: products, users: users}
}

func (h *ChatHandler) List(c *gin.Context) {
	userID := c.MustGet("user_id").(bson.ObjectID)
	conversations, err := h.chats.ListConversations(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to list chats"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": conversations, "message": "chats loaded"})
}

func (h *ChatHandler) Start(c *gin.Context) {
	userID := c.MustGet("user_id").(bson.ObjectID)
	var req model.StartChatRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}
	productID, err := bson.ObjectIDFromHex(req.ProductID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid product id"})
		return
	}
	product, err := h.products.FindByID(c.Request.Context(), productID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load product"})
		return
	}
	if product == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "product not found"})
		return
	}
	if product.SellerID == userID {
		c.JSON(http.StatusBadRequest, gin.H{"error": "you cannot chat with your own shop"})
		return
	}
	buyer, err := h.users.FindByID(c.Request.Context(), userID)
	if err != nil || buyer == nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load buyer"})
		return
	}
	seller, err := h.users.FindByID(c.Request.Context(), product.SellerID)
	if err != nil || seller == nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load seller"})
		return
	}

	conversation, err := h.chats.StartConversation(c.Request.Context(), &model.Conversation{
		BuyerID:      userID,
		SellerID:     product.SellerID,
		ProductID:    product.ID,
		ProductName:  product.Name,
		ProductImage: firstProductImage(product.Images),
		SellerName:   displaySellerName(product.SellerName, seller),
		BuyerName:    displayUserName(buyer),
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to start chat"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": conversation, "message": "chat ready"})
}

func (h *ChatHandler) Messages(c *gin.Context) {
	conversation, ok := h.loadConversation(c)
	if !ok {
		return
	}
	messages, err := h.chats.ListMessages(c.Request.Context(), conversation.ID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to list messages"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": messages, "message": "messages loaded"})
}

func (h *ChatHandler) Send(c *gin.Context) {
	userID := c.MustGet("user_id").(bson.ObjectID)
	conversation, ok := h.loadConversation(c)
	if !ok {
		return
	}
	var req model.SendChatMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}
	text, image, messageType, valid := normalizeChatMessageRequest(req.Text, req.Image)
	if !valid {
		c.JSON(http.StatusBadRequest, gin.H{"error": "message text or a valid image is required"})
		return
	}
	user, err := h.users.FindByID(c.Request.Context(), userID)
	if err != nil || user == nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load sender"})
		return
	}
	message, err := h.chats.SendMessage(c.Request.Context(), *conversation, userID, displayUserName(user), text, image, messageType)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to send message"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"data": message, "message": "message sent"})
}

func (h *ChatHandler) Read(c *gin.Context) {
	userID := c.MustGet("user_id").(bson.ObjectID)
	conversation, ok := h.loadConversation(c)
	if !ok {
		return
	}
	if err := h.chats.MarkRead(c.Request.Context(), *conversation, userID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to mark chat read"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": nil, "message": "chat marked read"})
}

func (h *ChatHandler) loadConversation(c *gin.Context) (*model.Conversation, bool) {
	userID := c.MustGet("user_id").(bson.ObjectID)
	conversationID, err := bson.ObjectIDFromHex(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid chat id"})
		return nil, false
	}
	conversation, err := h.chats.FindConversationForUser(c.Request.Context(), conversationID, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load chat"})
		return nil, false
	}
	if conversation == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "chat not found"})
		return nil, false
	}
	return conversation, true
}

func normalizeChatMessageRequest(text, image string) (string, string, string, bool) {
	trimmedText := strings.TrimSpace(text)
	trimmedImage := strings.TrimSpace(image)
	if len(trimmedText) > maxChatTextLength {
		return "", "", "", false
	}
	if trimmedImage != "" {
		if !strings.HasPrefix(trimmedImage, "data:image/jpeg;base64,") &&
			!strings.HasPrefix(trimmedImage, "data:image/png;base64,") {
			return "", "", "", false
		}
		if len(trimmedImage) > maxChatImageLength {
			return "", "", "", false
		}
		return trimmedText, trimmedImage, model.MessageTypeImage, true
	}
	if trimmedText == "" {
		return "", "", "", false
	}
	return trimmedText, "", model.MessageTypeText, true
}

func firstProductImage(images []string) string {
	if len(images) == 0 {
		return ""
	}
	return images[0]
}

func displaySellerName(productSellerName string, seller *model.User) string {
	if strings.TrimSpace(productSellerName) != "" {
		return strings.TrimSpace(productSellerName)
	}
	if strings.TrimSpace(seller.ShopName) != "" {
		return strings.TrimSpace(seller.ShopName)
	}
	return displayUserName(seller)
}

func displayUserName(user *model.User) string {
	name := strings.TrimSpace(strings.TrimSpace(user.Name) + " " + strings.TrimSpace(user.Lastname))
	if name != "" {
		return name
	}
	return user.Email
}
