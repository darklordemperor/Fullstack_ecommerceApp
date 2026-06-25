import '../../../core/dio/dio_client.dart';
import '../model/chat_model.dart';

class ChatRepository {
  Future<List<ChatSummaryModel>> list(String currentUserId) async {
    final response = await DioClient.dio.get('/chats');
    final data = DioClient.payload(response) as List? ?? const [];
    return data
        .map((item) => ChatSummaryModel.fromJson(
              Map<String, dynamic>.from(item),
              currentUserId: currentUserId,
            ))
        .toList();
  }

  Future<ChatSummaryModel> start(
    String productId,
    String currentUserId,
  ) async {
    final response = await DioClient.dio.post(
      '/chats/start',
      data: {'product_id': productId},
    );
    return ChatSummaryModel.fromJson(
      Map<String, dynamic>.from(DioClient.payload(response)),
      currentUserId: currentUserId,
    );
  }

  Future<List<ChatMessageModel>> messages(
    String conversationId,
    String currentUserId,
  ) async {
    final response = await DioClient.dio.get('/chats/$conversationId/messages');
    final data = DioClient.payload(response) as List? ?? const [];
    return data
        .map((item) => ChatMessageModel.fromJson(
              Map<String, dynamic>.from(item),
              currentUserId: currentUserId,
            ))
        .toList();
  }

  Future<ChatMessageModel> send(
    String conversationId, {
    String text = '',
    String image = '',
    required String currentUserId,
  }) async {
    final response = await DioClient.dio.post(
      '/chats/$conversationId/messages',
      data: {'text': text, 'image': image},
    );
    return ChatMessageModel.fromJson(
      Map<String, dynamic>.from(DioClient.payload(response)),
      currentUserId: currentUserId,
    );
  }

  Future<void> markRead(String conversationId) async {
    await DioClient.dio.post('/chats/$conversationId/read');
  }
}
