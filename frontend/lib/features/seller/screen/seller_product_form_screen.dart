import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/widget/app_ui.dart';
import '../../product/provider/product_provider.dart';
import '../provider/seller_provider.dart';

class SellerProductFormScreen extends ConsumerStatefulWidget {
  const SellerProductFormScreen({super.key, this.productId});

  final String? productId;

  @override
  ConsumerState<SellerProductFormScreen> createState() =>
      _SellerProductFormScreenState();
}

class _SellerProductFormScreenState
    extends ConsumerState<SellerProductFormScreen> {
  final formKey = GlobalKey<FormState>();
  final picker = ImagePicker();
  final name = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController();
  final stock = TextEditingController();
  final images = <String>[];
  String category = 'Electronics';
  bool filled = false;
  bool saving = false;

  static const categories = [
    'Electronics',
    'Fashion',
    'Food',
    'Sports',
    'Beauty'
  ];

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    price.dispose();
    stock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.productId == null
        ? null
        : ref.watch(productDetailProvider(widget.productId!));
    product?.whenData((p) {
      if (filled) return;
      filled = true;
      name.text = p.name;
      description.text = p.description;
      price.text = p.price == 0 ? '' : p.price.toStringAsFixed(2);
      stock.text = '${p.stock}';
      category =
          categories.contains(p.category) ? p.category : categories.first;
      images
        ..clear()
        ..addAll(p.images);
    });

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/seller'),
        title:
            Text(widget.productId == null ? 'Create Product' : 'Edit Product'),
      ),
      body: product?.isLoading == true
          ? const Center(child: CircularProgressIndicator())
          : product?.hasError == true
              ? AppErrorState(
                  message: friendlyError(product!.error!),
                  onRetry: () =>
                      ref.invalidate(productDetailProvider(widget.productId!)))
              : Form(
                  key: formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextFormField(
                        controller: name,
                        decoration: const InputDecoration(
                            labelText: 'Product name',
                            prefixIcon: Icon(Icons.sell_outlined)),
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter a product name.'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: description,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                            labelText: 'Description',
                            prefixIcon: Icon(Icons.description_outlined)),
                        validator: (value) => value == null ||
                                value.trim().length < 10
                            ? 'Describe the product in at least 10 characters.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: price,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          _PriceInputFormatter(),
                        ],
                        decoration: const InputDecoration(
                            labelText: 'Price',
                            prefixText: '\u0E3F ',
                            prefixIcon: Icon(Icons.payments_outlined)),
                        validator: (value) {
                          final parsed = double.tryParse(value ?? '');
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a price greater than 0.';
                          }
                          if (parsed > 1000000) {
                            return 'Price cannot be over \u0E3F1,000,000.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: stock,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        decoration: const InputDecoration(
                            labelText: 'Stock quantity',
                            prefixIcon: Icon(Icons.inventory_2_outlined)),
                        validator: (value) {
                          final parsed = int.tryParse(value ?? '');
                          if (parsed == null) return 'Enter available stock.';
                          if (parsed > 99) return 'Stock cannot be over 99.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: category,
                        items: categories
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => category = v ?? category),
                        decoration: const InputDecoration(
                            labelText: 'Category',
                            prefixIcon: Icon(Icons.category_outlined)),
                      ),
                      const SizedBox(height: 18),
                      Text('Product images',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      if (images.isEmpty)
                        const AppEmptyState(
                          icon: Icons.add_photo_alternate_outlined,
                          title: 'Add at least one image',
                          message:
                              'Choose a product photo from your gallery or take one with the camera.',
                        )
                      else
                        SizedBox(
                          height: 112,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: images.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (_, i) => Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: AppProductImage(
                                      image: images[i],
                                      width: 112,
                                      height: 112),
                                ),
                                Positioned(
                                  right: 4,
                                  top: 4,
                                  child: IconButton.filledTonal(
                                    icon: const Icon(Icons.close),
                                    onPressed: () =>
                                        setState(() => images.removeAt(i)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                              child: OutlinedButton.icon(
                                  onPressed: () =>
                                      pickImage(ImageSource.gallery),
                                  icon:
                                      const Icon(Icons.photo_library_outlined),
                                  label: const Text('Gallery'))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: OutlinedButton.icon(
                                  onPressed: () =>
                                      pickImage(ImageSource.camera),
                                  icon: const Icon(Icons.photo_camera_outlined),
                                  label: const Text('Camera'))),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: saving ? null : save,
                        child: Text(saving ? 'Saving...' : 'Save product'),
                      ),
                    ],
                  ),
                ),
    );
  }

  Future<void> pickImage(ImageSource source) async {
    if (!await ensureImagePermission(context, source)) return;
    final picked = await picker.pickImage(
        source: source, imageQuality: 78, maxWidth: 1200);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      images.add('data:image/jpeg;base64,${base64Encode(bytes)}');
    });
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    if (images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one product image.')));
      return;
    }

    setState(() => saving = true);
    final body = {
      'name': name.text.trim(),
      'description': description.text.trim(),
      'price': double.parse(price.text),
      'stock': int.parse(stock.text),
      'category': category,
      'images': images,
    };
    final repo = ref.read(productRepositoryProvider);
    try {
      if (widget.productId == null) {
        await repo.create(body);
      } else {
        await repo.update(widget.productId!, body);
      }
      await refreshSeller(ref);
      if (mounted) goBack(context, fallback: '/seller');
    } on DioException catch (error) {
      if (mounted) {
        final message = error.response?.data['error']?.toString() ??
            'Unable to save product. Please check the product details.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class _PriceInputFormatter extends TextInputFormatter {
  static final _notPriceChars = RegExp(r'[^0-9.]');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(_notPriceChars, '');
    if (text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final dotIndex = text.indexOf('.');
    var whole = dotIndex == -1 ? text : text.substring(0, dotIndex);
    var decimal = dotIndex == -1 ? '' : text.substring(dotIndex + 1);

    whole = whole.length > 7 ? whole.substring(0, 7) : whole;
    decimal = decimal.replaceAll('.', '');
    decimal = decimal.length > 2 ? decimal.substring(0, 2) : decimal;

    final nextText = dotIndex == -1 ? whole : '$whole.$decimal';
    return TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }
}
