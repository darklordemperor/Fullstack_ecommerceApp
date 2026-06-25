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
