import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../provider/cart_provider.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Cart')),
      bottomNavigationBar: cart.valueOrNull == null ? null : SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: Text('Total: ${NumberFormat.currency(locale: 'th_TH', symbol: '฿').format(cart.value!.total)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            FilledButton(
              onPressed: cart.value!.items.isEmpty ? null : () async {
                await ref.read(cartRepositoryProvider).clear();
                ref.invalidate(cartProvider);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order placed successfully!')));
              },
              child: const Text('Checkout'),
            ),
          ]),
        ),
      ),
      body: cart.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (value) => ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: value.items.length,
          itemBuilder: (_, i) {
            final item = value.items[i];
            return Dismissible(
              key: ValueKey(item.productId),
              onDismissed: (_) async { await ref.read(cartRepositoryProvider).remove(item.productId); ref.invalidate(cartProvider); },
              child: Card(
                child: ListTile(
                  leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: item.image, width: 80, height: 80, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.image))),
                  title: Text(item.name),
                  subtitle: Text('${NumberFormat.currency(locale: 'th_TH', symbol: '฿').format(item.price)} x ${item.quantity}'),
                  trailing: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                    IconButton(icon: const Icon(Icons.remove), onPressed: item.quantity > 1 ? () async { await ref.read(cartRepositoryProvider).update(item.productId, item.quantity - 1); ref.invalidate(cartProvider); } : null),
                    Text('${item.quantity}'),
                    IconButton(icon: const Icon(Icons.add), onPressed: () async { await ref.read(cartRepositoryProvider).update(item.productId, item.quantity + 1); ref.invalidate(cartProvider); }),
                    IconButton(icon: const Icon(Icons.delete), onPressed: () async { await ref.read(cartRepositoryProvider).remove(item.productId); ref.invalidate(cartProvider); }),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
