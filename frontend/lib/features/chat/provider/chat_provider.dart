import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/provider/auth_provider.dart';
import '../model/chat_model.dart';
import '../repository/chat_repository.dart';

final chatRepositoryProvider = Provider((ref) => ChatRepository());

final chatSummariesProvider =
    FutureProvider<List<ChatSummaryModel>>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return const [];
  return ref.watch(chatRepositoryProvider).list(user.id);
});

final chatUnreadCountProvider = Provider<int>((ref) {
  final summaries = ref.watch(chatSummariesProvider);
  return summaries.valueOrNull
          ?.fold<int>(0, (total, chat) => total + chat.unreadCount) ??
      0;
});

final chatMessagesProvider =
    FutureProvider.family<List<ChatMessageModel>, String>((ref, id) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return const [];
  await ref.watch(chatRepositoryProvider).markRead(id);
  return ref.watch(chatRepositoryProvider).messages(id, user.id);
});
