# MongoDB Chat System Design

## Goal

Add a real backend-persistent chat system to the ecommerce Flutter app so buyers can contact sellers from a product detail page and users can open their chat history from a sticky chat icon near the cart icon. The UI should take inspiration from Shopee-style ecommerce chat, while matching the existing app theme, spacing, colors, and Riverpod/Go/MongoDB conventions.

## Scope

This first version is REST-backed and persistent. It does not require WebSocket or push notification support. Users manually refresh or re-enter a chat to see new messages. The design keeps the data model ready for later realtime delivery.

Included:

- Chat history screen for the authenticated user.
- Product detail chat button beside the existing buy action.
- Chat room screen with seller header, product preview, message bubbles, image attachment, and bottom input bar.
- MongoDB persistence for conversations and messages.
- Two-year retention cleanup for message data.
- Backend authorization so users can only read/write their own conversations.
- Focused backend and Flutter tests.

Excluded from this version:

- WebSocket/SSE realtime updates.
- Push notifications.
- Message search.
- Moderation/admin chat tools.
- External object storage for images.

## Backend Design

Use the existing Go + Gin + MongoDB backend. Add a chat model, repository, and handler following the current `internal/model`, `internal/repository`, and `internal/handler` layout.

Collections:

- `conversations`
- `chat_messages`

Conversation fields:

- `_id`
- `buyer_id`
- `seller_id`
- `product_id`
- `product_name`
- `product_image`
- `seller_name`
- `buyer_name`
- `last_message`
- `last_message_type`: `text` or `image`
- `last_sender_id`
- `buyer_unread_count`
- `seller_unread_count`
- `created_at`
- `updated_at`

Message fields:

- `_id`
- `conversation_id`
- `sender_id`
- `sender_name`
- `text`
- `image`
- `message_type`: `text` or `image`
- `created_at`
- `expires_at`

Indexes:

- `conversations`: `{ buyer_id: 1, updated_at: -1 }`
- `conversations`: `{ seller_id: 1, updated_at: -1 }`
- `conversations`: unique `{ buyer_id: 1, seller_id: 1, product_id: 1 }`
- `chat_messages`: `{ conversation_id: 1, created_at: 1 }`
- `chat_messages`: TTL `{ expires_at: 1 }`, `expireAfterSeconds: 0`

Retention:

- Each message gets `expires_at = created_at + 2 years`.
- MongoDB TTL removes expired messages automatically.
- Conversations are kept as summaries, but message history older than two years is cleaned. If all messages expire, the conversation remains with the last summary until new activity or future cleanup work.

## Backend API

All endpoints require auth middleware.

`GET /api/chats`

- Returns the current user's conversation summaries ordered by `updated_at` descending.
- For a buyer, unread count comes from `buyer_unread_count`.
- For a seller, unread count comes from `seller_unread_count`.

`POST /api/chats/start`

Request:

```json
{
  "product_id": "..."
}
```

Behavior:

- Loads the product.
- Rejects if the current user is the product seller.
- Creates or returns the unique buyer/seller/product conversation.
- Captures product and participant display data for stable chat previews.

`GET /api/chats/:id/messages`

- Verifies the current user is the buyer or seller.
- Returns messages ordered ascending by `created_at`.

`POST /api/chats/:id/messages`

Request:

```json
{
  "text": "Hello",
  "image": "data:image/jpeg;base64,..."
}
```

Validation:

- At least one of `text` or `image` is required.
- Text is trimmed and capped at 2,000 characters.
- Image must be a data URL with `data:image/jpeg;base64,` or `data:image/png;base64,`.
- Decoded image payload is capped at 1 MB for this first version.

Behavior:

- Inserts a message with `expires_at` two years in the future.
- Updates conversation summary and increments the recipient unread count.

`POST /api/chats/:id/read`

- Verifies participant access.
- Clears the current user's unread count for that conversation.

## Frontend Design

Add `frontend/lib/features/chat/` with:

- `model/chat_model.dart`
- `repository/chat_repository.dart`
- `provider/chat_provider.dart`
- `screen/chat_list_screen.dart`
- `screen/chat_room_screen.dart`

Routing:

- `/chats` opens chat history.
- `/chats/:id` opens a chat room.

Home screen:

- Add a chat icon in the top-right app bar near the cart icon.
- Show a small unread badge from the chat summary provider.
- Use `context.push('/chats')`.

Product detail:

- Replace the current two-button footer layout with three actions: add to cart, chat, buy now.
- Chat action calls `POST /api/chats/start` and navigates to `/chats/:id`.
- Keep buy now prominent and preserve current behavior.

Chat list screen:

- App bar title: `Chats`.
- Conversation rows show seller/buyer avatar fallback, name, product name or latest message, date, and unread badge.
- Empty state invites the user to start a conversation from a product page.
- Error and loading states use existing `AppErrorState` and progress UI patterns.

Chat room screen:

- App bar shows seller or buyer name.
- Top product preview shows image, product name, and a compact action to view the product.
- Message area uses left/right bubbles:
  - Current user messages align right and use the app primary tint.
  - Other user messages align left with neutral surface color.
  - Image messages render as tappable rounded thumbnails.
- Bottom input includes attach image, text field, and send button.
- Image picking uses existing image picker conventions and stores a compressed data URL in MongoDB for this version.

## State Management

Use Riverpod consistently with the current app:

- `chatRepositoryProvider`
- `chatSummariesProvider` as a `FutureProvider<List<ChatSummaryModel>>`
- `chatMessagesProvider(conversationId)` as a `FutureProvider.family<List<ChatMessageModel>, String>`
- Simple local widget state for draft text and selected image before sending.

After sending a message:

- Invalidate the message provider for the conversation.
- Invalidate chat summaries so the unread/last-message state updates.

## Security And Validation

- All chat endpoints require JWT auth.
- Repository methods verify that the current user is a participant before returning or mutating a conversation.
- Users cannot start chat with themselves as seller.
- Backend validates image prefix and approximate decoded size.
- No secrets or auth tokens are stored in messages.
- Data URLs are acceptable for the resume-scale app, but external object storage should replace them before production use at larger scale.

## Testing

Backend tests:

- Starting a chat creates or reuses one conversation for the same buyer/seller/product.
- Non-participants cannot read or send messages.
- Sending text updates last message and unread count.
- Sending an image message stores message type and summary correctly.
- Read endpoint clears the current user's unread count.

Flutter tests:

- Product detail exposes a chat action.
- Chat list renders conversation summaries and unread badges.
- Chat room sends text and image messages through the repository.
- Empty/loading/error states render for chat list and room.

Verification commands:

```bash
cd /home/apirat/projects/Fullstack_ecommerceApp/backend
go test ./...

cd /home/apirat/projects/Fullstack_ecommerceApp/frontend
flutter analyze
flutter test
```

## Implementation Notes

- Keep the first implementation REST-only and avoid new production dependencies unless the existing stack cannot support a requirement.
- Use MongoDB TTL on `expires_at` for the two-year retention rule.
- Follow existing backend response shape through `success`, `data`, and `error` conventions already used by handlers.
- Match the Flutter app's current theme instead of copying the reference images directly.
