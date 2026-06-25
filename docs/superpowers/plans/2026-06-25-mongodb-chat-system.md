# MongoDB Chat System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a real MongoDB-persistent buyer/seller chat system with chat history, product-detail chat entry, message bubbles, image messages, unread counts, and two-year message retention.

**Architecture:** Add REST chat APIs to the existing Go/Gin/MongoDB backend, following the existing model/repository/handler structure. Add a Flutter `features/chat` module using the existing Dio/Riverpod patterns, then wire chat routes into `go_router`, the home app bar, and product detail actions.

**Tech Stack:** Go 1.23, Gin, MongoDB driver v2, Flutter, Riverpod, Dio, GoRouter, ImagePicker.

---

## File Structure

Backend files:

- Create `backend/internal/model/chat.go`: conversation/message structs plus request DTOs.
- Create `backend/internal/repository/chat_repo.go`: MongoDB chat persistence, participant checks, unread updates, TTL-backed message insert.
- Create `backend/internal/handler/chat_handler.go`: authenticated REST endpoints and validation.
- Create `backend/internal/handler/chat_handler_test.go`: pure handler/helper validation tests.
- Modify `backend/internal/db/mongo.go`: create conversation/message indexes and TTL index.
- Modify `backend/cmd/main.go`: construct chat repository/handler and register `/api/chats` routes.

Frontend files:

- Create `frontend/lib/features/chat/model/chat_model.dart`: summary/message DTO parsing.
- Create `frontend/lib/features/chat/repository/chat_repository.dart`: Dio calls for chat APIs.
- Create `frontend/lib/features/chat/provider/chat_provider.dart`: Riverpod repository, summary, unread, and message providers.
- Create `frontend/lib/features/chat/screen/chat_list_screen.dart`: conversation history UI.
- Create `frontend/lib/features/chat/screen/chat_room_screen.dart`: message room UI with image attachment.
- Modify `frontend/lib/core/router/app_router.dart`: add `/chats` and `/chats/:id` routes.
- Modify `frontend/lib/features/home/screen/home_screen.dart`: add sticky chat icon near cart icon.
- Modify `frontend/lib/features/product/screen/product_detail_screen.dart`: add chat action beside buy action.
- Create/update Flutter tests under `frontend/test/`.

---

## Task 1: Backend Chat Models And Indexes

**Files:**
- Create: `backend/internal/model/chat.go`
- Modify: `backend/internal/db/mongo.go`

- [ ] **Step 1: Add chat model structs**

Create `backend/internal/model/chat.go`:

```go
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
```

- [ ] **Step 2: Add MongoDB indexes**

Modify `backend/internal/db/mongo.go` so `ensureIndexes` creates chat indexes after existing user/product indexes:

```go
	if _, err = m.Database.Collection("conversations").Indexes().CreateMany(ctx, []mongo.IndexModel{
		{Keys: bson.D{{Key: "buyer_id", Value: 1}, {Key: "updated_at", Value: -1}}},
		{Keys: bson.D{{Key: "seller_id", Value: 1}, {Key: "updated_at", Value: -1}}},
		{
			Keys: bson.D{{Key: "buyer_id", Value: 1}, {Key: "seller_id", Value: 1}, {Key: "product_id", Value: 1}},
			Options: options.Index().SetUnique(true),
		},
	}); err != nil {
		return err
	}
	_, err = m.Database.Collection("chat_messages").Indexes().CreateMany(ctx, []mongo.IndexModel{
		{Keys: bson.D{{Key: "conversation_id", Value: 1}, {Key: "created_at", Value: 1}}},
		{
			Keys: bson.D{{Key: "expires_at", Value: 1}},
			Options: options.Index().SetExpireAfterSeconds(0),
		},
	})
	return err
```

- [ ] **Step 3: Verify backend compiles**

Run:

```bash
cd /home/apirat/projects/Fullstack_ecommerceApp/backend
go test ./...
```

Expected: existing tests pass.

---

## Task 2: Backend Repository And Validation Helpers

**Files:**
- Create: `backend/internal/repository/chat_repo.go`
- Create: `backend/internal/handler/chat_handler_test.go`
- Create/modify: `backend/internal/handler/chat_handler.go`

- [ ] **Step 1: Write validation tests first**

Create `backend/internal/handler/chat_handler_test.go`:

```go
package handler

import "testing"

func TestNormalizeChatMessageRequestRequiresTextOrImage(t *testing.T) {
	text, image, messageType, ok := normalizeChatMessageRequest("   ", "")
	if ok || text != "" || image != "" || messageType != "" {
		t.Fatalf("expected empty request to be invalid, got text=%q image=%q type=%q ok=%v", text, image, messageType, ok)
	}
}

func TestNormalizeChatMessageRequestAcceptsTrimmedText(t *testing.T) {
	text, image, messageType, ok := normalizeChatMessageRequest("  hello  ", "")
	if !ok || text != "hello" || image != "" || messageType != "text" {
		t.Fatalf("expected text message, got text=%q image=%q type=%q ok=%v", text, image, messageType, ok)
	}
}

func TestNormalizeChatMessageRequestRejectsLongText(t *testing.T) {
	longText := make([]byte, 2001)
	for i := range longText {
		longText[i] = 'a'
	}
	_, _, _, ok := normalizeChatMessageRequest(string(longText), "")
	if ok {
		t.Fatal("expected long text to be invalid")
	}
}

func TestNormalizeChatMessageRequestAcceptsImageDataURL(t *testing.T) {
	_, image, messageType, ok := normalizeChatMessageRequest("", "data:image/jpeg;base64,abcd")
	if !ok || image == "" || messageType != "image" {
		t.Fatalf("expected image message, got image=%q type=%q ok=%v", image, messageType, ok)
	}
}

func TestNormalizeChatMessageRequestRejectsUnsupportedImageDataURL(t *testing.T) {
	_, _, _, ok := normalizeChatMessageRequest("", "data:image/gif;base64,abcd")
	if ok {
		t.Fatal("expected unsupported image data URL to be invalid")
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd /home/apirat/projects/Fullstack_ecommerceApp/backend
go test ./internal/handler -run TestNormalizeChatMessageRequest
```

Expected: FAIL because `normalizeChatMessageRequest` does not exist.

- [ ] **Step 3: Implement chat repository**

Create `backend/internal/repository/chat_repo.go` with methods:

```go
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
	return conversations, nil
}

func (r *ChatRepository) FindConversationForUser(ctx context.Context, id, userID bson.ObjectID) (*model.Conversation, error) {
	var conversation model.Conversation
	err := r.conversations.FindOne(ctx, bson.M{
		"_id": id,
		"$or": []bson.M{{"buyer_id": userID}, {"seller_id": userID}},
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
	filter := bson.M{"buyer_id": conversation.BuyerID, "seller_id": conversation.SellerID, "product_id": conversation.ProductID}
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
	return messages, nil
}

func (r *ChatRepository) SendMessage(ctx context.Context, conversation model.Conversation, senderID bson.ObjectID, senderName, text, image, messageType string) (*model.ChatMessage, error) {
	now := time.Now()
	message := &model.ChatMessage{
		ID: bson.NewObjectID(), ConversationID: conversation.ID, SenderID: senderID,
		SenderName: senderName, Text: text, Image: image, MessageType: messageType,
		CreatedAt: now, ExpiresAt: now.AddDate(2, 0, 0),
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
		"$set": bson.M{"last_message": preview, "last_message_type": messageType, "last_sender_id": senderID, "updated_at": now},
		"$inc": inc,
	})
	return message, err
}

func (r *ChatRepository) MarkRead(ctx context.Context, conversation model.Conversation, userID bson.ObjectID) error {
	field := "buyer_unread_count"
	if userID == conversation.SellerID {
		field = "seller_unread_count"
	}
	_, err := r.conversations.UpdateOne(ctx, bson.M{"_id": conversation.ID}, bson.M{"$set": bson.M{field: 0}})
	return err
}
```

- [ ] **Step 4: Implement handler skeleton and validation helper**

Create `backend/internal/handler/chat_handler.go` with `normalizeChatMessageRequest`, `NewChatHandler`, `List`, `Start`, `Messages`, `Send`, and `Read`. Use `c.MustGet("user_id").(bson.ObjectID)` for auth identity. `normalizeChatMessageRequest` must trim text, cap text to 2,000 chars, accept only JPEG/PNG data URLs, cap base64 body length to `1400000`, and return `model.MessageTypeText` or `model.MessageTypeImage`.

- [ ] **Step 5: Run validation tests**

Run:

```bash
cd /home/apirat/projects/Fullstack_ecommerceApp/backend
go test ./internal/handler -run TestNormalizeChatMessageRequest
```

Expected: PASS.

---

## Task 3: Backend Routes

**Files:**
- Modify: `backend/cmd/main.go`

- [ ] **Step 1: Wire repository and handler**

In `backend/cmd/main.go`, after `orderRepo := ...`, add:

```go
	chatRepo := repository.NewChatRepository(mongoDB.Database)
```

After `adminHandler := ...`, add:

```go
	chatHandler := handler.NewChatHandler(chatRepo, productRepo, userRepo)
```

- [ ] **Step 2: Register routes**

Before seller/admin groups, add:

```go
	chats := api.Group("/chats", middleware.Auth(cfg.JWTSecret))
	chats.GET("", chatHandler.List)
	chats.POST("/start", chatHandler.Start)
	chats.GET("/:id/messages", chatHandler.Messages)
	chats.POST("/:id/messages", chatHandler.Send)
	chats.POST("/:id/read", chatHandler.Read)
```

- [ ] **Step 3: Run backend verification**

Run:

```bash
cd /home/apirat/projects/Fullstack_ecommerceApp/backend
go test ./...
```

Expected: PASS.

---

## Task 4: Flutter Chat Data Layer

**Files:**
- Create: `frontend/lib/features/chat/model/chat_model.dart`
- Create: `frontend/lib/features/chat/repository/chat_repository.dart`
- Create: `frontend/lib/features/chat/provider/chat_provider.dart`
- Create: `frontend/test/chat_model_test.dart`

- [ ] **Step 1: Write model tests**

Create `frontend/test/chat_model_test.dart`:

```dart
import 'package:ecommerce_frontend/features/chat/model/chat_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat summary parses unread count for current user', () {
    final summary = ChatSummaryModel.fromJson({
      'id': 'c1',
      'buyer_id': 'buyer',
      'seller_id': 'seller',
      'product_id': 'p1',
      'product_name': 'Keyboard',
      'product_image': 'image',
      'seller_name': 'Seller Shop',
      'buyer_name': 'Buyer One',
      'last_message': 'Hello',
      'last_message_type': 'text',
      'buyer_unread_count': 2,
      'seller_unread_count': 3,
      'updated_at': '2026-06-25T10:00:00Z',
    }, currentUserId: 'buyer');

    expect(summary.title, 'Seller Shop');
    expect(summary.unreadCount, 2);
    expect(summary.productName, 'Keyboard');
  });

  test('chat message detects current user ownership', () {
    final message = ChatMessageModel.fromJson({
      'id': 'm1',
      'conversation_id': 'c1',
      'sender_id': 'u1',
      'sender_name': 'User',
      'text': 'Hi',
      'image': '',
      'message_type': 'text',
      'created_at': '2026-06-25T10:00:00Z',
    }, currentUserId: 'u1');

    expect(message.isMine, isTrue);
    expect(message.isImage, isFalse);
  });
}
```

- [ ] **Step 2: Run model tests to verify failure**

Run:

```bash
cd /home/apirat/projects/Fullstack_ecommerceApp/frontend
flutter test test/chat_model_test.dart
```

Expected: FAIL because chat model does not exist.

- [ ] **Step 3: Implement models**

Create `ChatSummaryModel` and `ChatMessageModel` with the fields used in the tests. Add `title`, `subtitle`, `unreadCount`, `isMine`, and `isImage` getters.

- [ ] **Step 4: Implement repository and providers**

`chat_repository.dart` methods:

```dart
Future<List<ChatSummaryModel>> list(String currentUserId)
Future<ChatSummaryModel> start(String productId, String currentUserId)
Future<List<ChatMessageModel>> messages(String conversationId, String currentUserId)
Future<ChatMessageModel> send(String conversationId, {String text = '', String image = '', required String currentUserId})
Future<void> markRead(String conversationId)
```

`chat_provider.dart` providers:

```dart
final chatRepositoryProvider = Provider((ref) => ChatRepository());
final chatSummariesProvider = FutureProvider<List<ChatSummaryModel>>((ref) async { ... });
final chatUnreadCountProvider = Provider<int>((ref) { ... });
final chatMessagesProvider = FutureProvider.family<List<ChatMessageModel>, String>((ref, id) async { ... });
```

- [ ] **Step 5: Run Flutter model tests**

Run:

```bash
cd /home/apirat/projects/Fullstack_ecommerceApp/frontend
flutter test test/chat_model_test.dart
```

Expected: PASS.

---

## Task 5: Flutter Chat Routes And Screens

**Files:**
- Create: `frontend/lib/features/chat/screen/chat_list_screen.dart`
- Create: `frontend/lib/features/chat/screen/chat_room_screen.dart`
- Modify: `frontend/lib/core/router/app_router.dart`

- [ ] **Step 1: Add routes**

Import chat screens in `app_router.dart` and add:

```dart
GoRoute(path: '/chats', builder: (_, __) => const ChatListScreen()),
GoRoute(
  path: '/chats/:id',
  builder: (_, s) => ChatRoomScreen(id: s.pathParameters['id']!),
),
```

- [ ] **Step 2: Implement chat list screen**

Create a `ConsumerWidget` with `AppBar(title: Text(tr(ref, 'Chats', 'แชท')))` and a `ListView.separated` over `chatSummariesProvider`. Each row shows image/avatar, title, subtitle, updated date, and a red unread badge when `unreadCount > 0`.

- [ ] **Step 3: Implement chat room screen**

Create a `ConsumerStatefulWidget` with:

- `TextEditingController` for draft text.
- `String selectedImage = ''`.
- `ImagePicker` to pick/compress images.
- `ListView` for bubbles from `chatMessagesProvider(id)`.
- Bottom input bar with attach image, text field, and send button.
- `send()` calls repository, clears local draft/image, invalidates `chatMessagesProvider(id)` and `chatSummariesProvider`.

- [ ] **Step 4: Run Flutter analysis**

Run:

```bash
cd /home/apirat/projects/Fullstack_ecommerceApp/frontend
flutter analyze
```

Expected: no analyzer errors.

---

## Task 6: Home And Product Entry Points

**Files:**
- Modify: `frontend/lib/features/home/screen/home_screen.dart`
- Modify: `frontend/lib/features/product/screen/product_detail_screen.dart`

- [ ] **Step 1: Add home chat icon**

In the `HomeScreen` app bar actions, add a chat icon before cart:

```dart
Consumer(
  builder: (context, ref, _) {
    final unread = ref.watch(chatUnreadCountProvider);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: tr(ref, 'Chats', 'แชท'),
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          onPressed: () => context.push('/chats'),
        ),
        if (unread > 0) Positioned(...),
      ],
    );
  },
)
```

- [ ] **Step 2: Add product detail chat action**

In `ProductDetailScreen`, change the bottom action row to include:

```dart
OutlinedButton.icon(
  onPressed: () async {
    final conversation = await ref.read(chatRepositoryProvider).start(
      widget.id,
      ref.read(authProvider).user!.id,
    );
    ref.invalidate(chatSummariesProvider);
    if (context.mounted) context.push('/chats/${conversation.id}');
  },
  icon: const Icon(Icons.chat_bubble_outline_rounded),
  label: Text(tr(ref, 'Chat', 'แชท')),
)
```

Keep add-to-cart and buy-now behavior intact.

- [ ] **Step 3: Run targeted Flutter tests**

Run:

```bash
cd /home/apirat/projects/Fullstack_ecommerceApp/frontend
flutter test
```

Expected: existing tests still pass.

---

## Task 7: Final Verification

**Files:**
- All modified files.

- [ ] **Step 1: Run backend tests**

```bash
cd /home/apirat/projects/Fullstack_ecommerceApp/backend
go test ./...
```

Expected: PASS.

- [ ] **Step 2: Run frontend tests and analysis**

```bash
cd /home/apirat/projects/Fullstack_ecommerceApp/frontend
flutter analyze
flutter test
```

Expected: PASS.

- [ ] **Step 3: Inspect git diff**

```bash
cd /home/apirat/projects/Fullstack_ecommerceApp
git diff --stat
git status --short
```

Expected: only chat feature files, router/home/product changes, docs plan, and tests are modified.

---

## Self-Review

Spec coverage:

- MongoDB persistence: Tasks 1-3.
- Two-year retention: Task 1 TTL index and Task 2 `ExpiresAt`.
- Authenticated chat APIs: Tasks 2-3.
- Chat history from top-right icon: Task 6.
- Product detail chat beside buy/buy-product actions: Task 6.
- Messenger/Shopee-style chat room with image support: Task 5.
- Riverpod state management: Task 4.
- Tests and verification: Tasks 2, 4, 6, and 7.

Placeholder scan:

- No incomplete markers or undefined feature scope remains.

Type consistency:

- Backend models use `Conversation`, `ChatMessage`, `StartChatRequest`, and `SendChatMessageRequest`.
- Frontend uses `ChatSummaryModel` and `ChatMessageModel`.
