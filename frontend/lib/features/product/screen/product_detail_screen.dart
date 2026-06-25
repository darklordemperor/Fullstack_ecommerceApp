import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/widget/app_ui.dart';
import '../../auth/provider/auth_provider.dart';
import '../../cart/provider/cart_provider.dart';
import '../../chat/provider/chat_provider.dart';
import '../provider/product_provider.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int quantity = 1;
  int page = 0;

  @override
  Widget build(BuildContext context) {
    final product = ref.watch(productDetailProvider(widget.id));
    return Scaffold(
      appBar: AppBar(
          leading: const AppBackButton(),
          title: Text(tr(ref, 'Product Detail', 'รายละเอียดสินค้า'))),
      bottomNavigationBar: product.valueOrNull == null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: const Border(top: BorderSide(color: AppTheme.line)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 22,
                      offset: Offset(0, -8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await ref
                              .read(cartRepositoryProvider)
                              .add(widget.id, quantity);
                          ref.invalidate(cartProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(tr(ref, 'Added to cart',
                                    'เพิ่มลงตะกร้าแล้ว'))));
                          }
                        },
                        child: Text(tr(ref, 'Add to Cart', 'เพิ่มลงตะกร้า')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => context.push(
                            '/checkout?productId=${widget.id}&quantity=$quantity'),
                        child: Text(tr(ref, 'Buy Now', 'ซื้อทันที')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 52,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => startChat(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Icon(Icons.chat_bubble_outline_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: product.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorState(
            message: friendlyError(e),
            onRetry: () => ref.invalidate(productDetailProvider(widget.id))),
        data: (item) {
          final images = item.images.isEmpty ? [item.mainImage] : item.images;
          return ListView(
            padding: const EdgeInsets.only(bottom: 20),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: PageView.builder(
                          itemCount: images.length,
                          onPageChanged: (value) =>
                              setState(() => page = value),
                          itemBuilder: (_, i) =>
                              AppProductImage(image: images[i]),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: _ImageCounter(
                        current: page + 1,
                        total: images.length,
                      ),
                    ),
                  ],
                ),
              ),
              if (images.length > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    images.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: i == page ? 18 : 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: i == page ? AppTheme.primary : AppTheme.line,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      NumberFormat.currency(
                              locale: moneyLocale(ref), symbol: '\u0E3F')
                          .format(item.price),
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    AppInfoPanel(
                      child: Row(
                        children: [
                          CircleAvatar(
                              backgroundColor:
                                  AppTheme.primary.withValues(alpha: .12),
                              child: Text(
                                item.sellerName.isNotEmpty
                                    ? item.sellerName[0].toUpperCase()
                                    : 'S',
                                style: const TextStyle(
                                    color: AppTheme.primaryDark),
                              )),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(item.sellerName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                          ),
                          _MetaChip(
                            icon: Icons.inventory_2_outlined,
                            label:
                                '${tr(ref, 'Stock', 'คงเหลือ')} ${item.stock}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _QuantityStepper(
                          value: quantity,
                          canDecrease: quantity > 1,
                          canIncrease: quantity < item.stock && quantity < 99,
                          onDecrease: () => setState(() => quantity--),
                          onIncrease: () => setState(() => quantity++),
                        ),
                        const Spacer(),
                        _MetaChip(
                          icon: Icons.category_outlined,
                          label: categoryLabel(ref, item.category),
                          highlighted: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    AppInfoPanel(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.primary.withValues(alpha: .10),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.notes_rounded,
                                  color: AppTheme.primaryDark,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                tr(ref, 'Description', 'รายละเอียด'),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            item.description.trim().isEmpty
                                ? tr(
                                    ref,
                                    'No product description has been added yet.',
                                    'ยังไม่มีรายละเอียดสินค้า')
                                : item.description.trim(),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  height: 1.55,
                                  fontSize: 15,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> startChat(BuildContext context) async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      context.go('/login?next=/products/${widget.id}');
      return;
    }
    try {
      final conversation =
          await ref.read(chatRepositoryProvider).start(widget.id, user.id);
      ref.invalidate(chatSummariesProvider);
      if (context.mounted) {
        context.push('/chats/${conversation.id}');
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(error))),
        );
      }
    }
  }
}

class _ImageCounter extends StatelessWidget {
  const _ImageCounter({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$current/$total',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = highlighted ? AppTheme.primaryDark : colors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: highlighted
            ? AppTheme.primary.withValues(alpha: .10)
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.value,
    required this.canDecrease,
    required this.canIncrease,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int value;
  final bool canDecrease;
  final bool canIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: AppLanguage.text('Decrease quantity', 'ลดจำนวน'),
            onPressed: canDecrease ? onDecrease : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 34,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            tooltip: AppLanguage.text('Increase quantity', 'เพิ่มจำนวน'),
            onPressed: canIncrease ? onIncrease : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}
