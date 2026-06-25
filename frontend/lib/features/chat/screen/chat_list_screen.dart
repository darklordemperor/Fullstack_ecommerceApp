import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widget/app_ui.dart';
import '../model/chat_model.dart';
import '../provider/chat_provider.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(chatSummariesProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(tr(ref, 'Chats', 'แชท')),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(chatSummariesProvider),
        child: chats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AppErrorState(
            message: friendlyError(e),
            onRetry: () => ref.invalidate(chatSummariesProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * .18),
                  AppEmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: tr(ref, 'No chats yet', 'ยังไม่มีแชท'),
                    message: tr(
                      ref,
                      'Open a product and start a conversation with the seller.',
                      'เปิดหน้าสินค้าแล้วเริ่มพูดคุยกับผู้ขาย',
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) => _ChatSummaryTile(chat: items[index]),
            );
          },
        ),
      ),
    );
  }
}

class _ChatSummaryTile extends ConsumerWidget {
  const _ChatSummaryTile({required this.chat});

  final ChatSummaryModel chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final date = chat.updatedAt == null
        ? ''
        : DateFormat('MMM d').format(chat.updatedAt!.toLocal());
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AppProductImage(
          image: chat.productImage,
          width: 58,
          height: 58,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              chat.title.isEmpty ? tr(ref, 'Shop', 'ร้านค้า') : chat.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          if (date.isNotEmpty)
            Text(
              date,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                chat.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
            if (chat.unreadCount > 0) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 12,
                backgroundColor: AppTheme.primary,
                child: Text(
                  chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      onTap: () => context.push('/chats/${chat.id}'),
    );
  }
}
