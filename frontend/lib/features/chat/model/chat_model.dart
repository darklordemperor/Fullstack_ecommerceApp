class ChatSummaryModel {
  const ChatSummaryModel({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.sellerName,
    required this.buyerName,
    required this.lastMessage,
    required this.lastMessageType,
    required this.buyerUnreadCount,
    required this.sellerUnreadCount,
    required this.updatedAt,
    required this.currentUserId,
  });

  final String id;
  final String buyerId;
  final String sellerId;
  final String productId;
  final String productName;
  final String productImage;
  final String sellerName;
  final String buyerName;
  final String lastMessage;
  final String lastMessageType;
  final int buyerUnreadCount;
  final int sellerUnreadCount;
  final DateTime? updatedAt;
  final String currentUserId;

  bool get isBuyer => currentUserId == buyerId;
  String get title => isBuyer ? sellerName : buyerName;
  String get subtitle {
    if (lastMessage.trim().isNotEmpty) return lastMessage.trim();
    return productName;
  }

  int get unreadCount => isBuyer ? buyerUnreadCount : sellerUnreadCount;

  factory ChatSummaryModel.fromJson(
    Map<String, dynamic> json, {
    required String currentUserId,
  }) {
    return ChatSummaryModel(
      id: json['id']?.toString() ?? '',
      buyerId: json['buyer_id']?.toString() ?? '',
      sellerId: json['seller_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      productImage: json['product_image']?.toString() ?? '',
      sellerName: json['seller_name']?.toString() ?? '',
      buyerName: json['buyer_name']?.toString() ?? '',
      lastMessage: json['last_message']?.toString() ?? '',
      lastMessageType: json['last_message_type']?.toString() ?? '',
      buyerUnreadCount: json['buyer_unread_count'] is num
          ? (json['buyer_unread_count'] as num).toInt()
          : 0,
      sellerUnreadCount: json['seller_unread_count'] is num
          ? (json['seller_unread_count'] as num).toInt()
          : 0,
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      currentUserId: currentUserId,
    );
  }
}

class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.image,
    required this.messageType,
    required this.createdAt,
    required this.currentUserId,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String text;
  final String image;
  final String messageType;
  final DateTime? createdAt;
  final String currentUserId;

  bool get isMine => senderId == currentUserId;
  bool get isImage => messageType == 'image' && image.isNotEmpty;

  factory ChatMessageModel.fromJson(
    Map<String, dynamic> json, {
    required String currentUserId,
  }) {
    return ChatMessageModel(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversation_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      senderName: json['sender_name']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      messageType: json['message_type']?.toString() ?? 'text',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      currentUserId: currentUserId,
    );
  }
}
