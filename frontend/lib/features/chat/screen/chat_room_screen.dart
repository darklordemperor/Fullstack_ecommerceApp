import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widget/app_ui.dart';
import '../../auth/provider/auth_provider.dart';
import '../model/chat_model.dart';
import '../provider/chat_provider.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final controller = TextEditingController();
  final picker = ImagePicker();
  String selectedImage = '';
  bool sending = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider(widget.id));
    final summary = _summaryFor(
      ref.watch(chatSummariesProvider).valueOrNull,
      widget.id,
    );
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/chats'),
        title: Text(summary?.title ?? tr(ref, 'Chat', 'แชท')),
      ),
      body: Column(
        children: [
          if (summary != null) _ProductPreview(summary: summary),
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => AppErrorState(
                message: friendlyError(e),
                onRetry: () => ref.invalidate(chatMessagesProvider(widget.id)),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.mark_chat_unread_outlined,
                    title: tr(ref, 'Start the conversation', 'เริ่มต้นบทสนทนา'),
                    message: tr(
                      ref,
                      'Ask the seller about this product.',
                      'สอบถามผู้ขายเกี่ยวกับสินค้านี้',
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
                  itemCount: items.length,
                  itemBuilder: (_, index) => _MessageBubble(
                    message: items[index],
                  ),
                );
              },
            ),
          ),
          _Composer(
            controller: controller,
            selectedImage: selectedImage,
            sending: sending,
            onPickImage: () => pickImage(ImageSource.gallery),
            onClearImage: () => setState(() => selectedImage = ''),
            onSend: send,
          ),
        ],
      ),
    );
  }

  Future<void> pickImage(ImageSource source) async {
    if (!await ensureImagePermission(context, source)) return;
    final picked =
        await picker.pickImage(source: source, imageQuality: 76, maxWidth: 900);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      selectedImage = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    });
  }

  Future<void> send() async {
    final text = controller.text.trim();
    if (text.isEmpty && selectedImage.isEmpty) return;
    final user = ref.read(authProvider).user;
    if (user == null) return;
    setState(() => sending = true);
    try {
      await ref.read(chatRepositoryProvider).send(
            widget.id,
            text: text,
            image: selectedImage,
            currentUserId: user.id,
          );
      controller.clear();
      selectedImage = '';
      ref.invalidate(chatMessagesProvider(widget.id));
      ref.invalidate(chatSummariesProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }
}

class _ProductPreview extends ConsumerWidget {
  const _ProductPreview({required this.summary});

  final ChatSummaryModel summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: () => context.push('/products/${summary.productId}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AppProductImage(
                  image: summary.productImage,
                  width: 52,
                  height: 52,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr(ref, 'View product', 'ดูสินค้า'),
                      style: const TextStyle(
                        color: AppTheme.primaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final align = message.isMine ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = message.isMine
        ? AppTheme.primary.withValues(alpha: .16)
        : colors.surfaceContainerHighest;
    final time = message.createdAt == null
        ? ''
        : DateFormat('HH:mm').format(message.createdAt!.toLocal());
    return Align(
      alignment: align,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .76,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(message.isMine ? 18 : 4),
            bottomRight: Radius.circular(message.isMine ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: message.isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (message.isImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AppProductImage(
                  image: message.image,
                  width: 220,
                  height: 170,
                ),
              ),
            if (message.text.isNotEmpty) ...[
              if (message.isImage) const SizedBox(height: 8),
              Text(
                message.text,
                style: const TextStyle(fontSize: 15, height: 1.35),
              ),
            ],
            if (time.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                time,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Composer extends ConsumerWidget {
  const _Composer({
    required this.controller,
    required this.selectedImage,
    required this.sending,
    required this.onPickImage,
    required this.onClearImage,
    required this.onSend,
  });

  final TextEditingController controller;
  final String selectedImage;
  final bool sending;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: const Border(top: BorderSide(color: AppTheme.line)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectedImage.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AppProductImage(
                        image: selectedImage,
                        width: 86,
                        height: 72,
                      ),
                    ),
                    Positioned(
                      right: 2,
                      top: 2,
                      child: InkWell(
                        onTap: onClearImage,
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.black54,
                          child:
                              Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  tooltip: tr(ref, 'Attach image', 'แนบรูปภาพ'),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  onPressed: sending ? null : onPickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: tr(ref, 'Type a message', 'พิมพ์ข้อความ'),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: sending ? null : onSend,
                  child: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

ChatSummaryModel? _summaryFor(List<ChatSummaryModel>? items, String id) {
  if (items == null) return null;
  for (final item in items) {
    if (item.id == id) return item;
  }
  return null;
}
