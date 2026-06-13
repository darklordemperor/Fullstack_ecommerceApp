import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widget/app_ui.dart';
import '../../cart/provider/cart_provider.dart';
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
          leading: const AppBackButton(), title: const Text('Product Detail')),
      bottomNavigationBar: product.valueOrNull == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
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
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Added to cart')));
                          }
                        },
                        child: const Text('Add to Cart'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => context.push(
                            '/checkout?productId=${widget.id}&quantity=$quantity'),
                        child: const Text('Buy Now'),
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
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: PageView.builder(
                  itemCount: images.length,
                  onPageChanged: (value) => setState(() => page = value),
                  itemBuilder: (_, i) => AppProductImage(image: images[i]),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  images.length,
                  (i) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == page
                            ? AppTheme.primary
                            : Colors.grey.shade300),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
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
                      NumberFormat.currency(locale: 'th_TH', symbol: '\u0E3F')
                          .format(item.price),
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                            child: Text(item.sellerName.isNotEmpty
                                ? item.sellerName[0].toUpperCase()
                                : 'S')),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item.sellerName)),
                        Chip(label: Text('Stock ${item.stock}')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IconButton(
                            onPressed: quantity > 1
                                ? () => setState(() => quantity--)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline)),
                        Text('$quantity',
                            style: Theme.of(context).textTheme.titleLarge),
                        IconButton(
                            onPressed: quantity < item.stock && quantity < 99
                                ? () => setState(() => quantity++)
                                : null,
                            icon: const Icon(Icons.add_circle_outline)),
                        const Spacer(),
                        Chip(label: Text(item.category)),
                      ],
                    ),
                    ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Description'),
                        children: [
                          Align(
                              alignment: Alignment.centerLeft,
                              child: Text(item.description))
                        ]),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
