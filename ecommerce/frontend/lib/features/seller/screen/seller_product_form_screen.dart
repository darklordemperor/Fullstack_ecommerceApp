import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../product/provider/product_provider.dart';
import '../provider/seller_provider.dart';

class SellerProductFormScreen extends ConsumerStatefulWidget {
  const SellerProductFormScreen({super.key, this.productId});
  final String? productId;

  @override
  ConsumerState<SellerProductFormScreen> createState() => _SellerProductFormScreenState();
}

class _SellerProductFormScreenState extends ConsumerState<SellerProductFormScreen> {
  final name = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController();
  final stock = TextEditingController();
  final images = <TextEditingController>[TextEditingController()];
  String category = 'Electronics';
  bool filled = false;
  static const categories = ['Electronics', 'Fashion', 'Food', 'Sports', 'Beauty'];

  @override
  Widget build(BuildContext context) {
    final product = widget.productId == null ? null : ref.watch(productDetailProvider(widget.productId!));
    product?.whenData((p) {
      if (filled) return;
      filled = true;
      name.text = p.name;
      description.text = p.description;
      price.text = '${p.price}';
      stock.text = '${p.stock}';
      category = categories.contains(p.category) ? p.category : categories.first;
      images
        ..clear()
        ..addAll((p.images.isEmpty ? [''] : p.images).map((url) => TextEditingController(text: url)));
    });
    return Scaffold(
      appBar: AppBar(title: Text(widget.productId == null ? 'Create Product' : 'Edit Product')),
      body: product?.isLoading == true ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          TextField(controller: description, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 12),
          TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price')),
          const SizedBox(height: 12),
          TextField(controller: stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: category, items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => category = v ?? category), decoration: const InputDecoration(labelText: 'Category')),
          const SizedBox(height: 12),
          for (var i = 0; i < images.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(child: TextField(controller: images[i], decoration: InputDecoration(labelText: 'Image URL ${i + 1}'))),
                IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: images.length == 1 ? null : () => setState(() => images.removeAt(i))),
              ]),
            ),
          TextButton.icon(onPressed: () => setState(() => images.add(TextEditingController())), icon: const Icon(Icons.add), label: const Text('Add image URL')),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: save, child: const Text('Save')),
        ],
      ),
    );
  }

  Future<void> save() async {
    final body = {
      'name': name.text.trim(),
      'description': description.text.trim(),
      'price': double.tryParse(price.text) ?? 0,
      'stock': int.tryParse(stock.text) ?? 0,
      'category': category,
      'images': images.map((c) => c.text.trim()).where((url) => url.isNotEmpty).toList(),
    };
    final repo = ref.read(productRepositoryProvider);
    if (widget.productId == null) {
      await repo.create(body);
    } else {
      await repo.update(widget.productId!, body);
    }
    await refreshSeller(ref);
    if (mounted) context.go('/seller');
  }
}
