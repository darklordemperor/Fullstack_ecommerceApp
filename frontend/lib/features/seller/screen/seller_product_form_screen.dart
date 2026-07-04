import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/settings/app_settings.dart';
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
        title: Text(widget.productId == null
            ? tr(ref, 'Create Product', 'สร้างสินค้า')
            : tr(ref, 'Edit Product', 'แก้ไขสินค้า')),
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
                        decoration: InputDecoration(
                            labelText: tr(ref, 'Product name', 'ชื่อสินค้า'),
                            prefixIcon: const Icon(Icons.sell_outlined)),
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? tr(ref, 'Enter a product name.',
                                    'กรุณากรอกชื่อสินค้า')
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: description,
                        minLines: 3,
                        maxLines: 5,
                        decoration: InputDecoration(
                            labelText: tr(ref, 'Description', 'รายละเอียด'),
                            prefixIcon: const Icon(Icons.description_outlined)),
                        validator: (value) => value == null ||
                                value.trim().length < 10
                            ? tr(
                                ref,
                                'Describe the product in at least 10 characters.',
                                'กรุณาอธิบายสินค้าอย่างน้อย 10 ตัวอักษร')
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
                        decoration: InputDecoration(
                            labelText: tr(ref, 'Price', 'ราคา'),
                            prefixText: '\u0E3F ',
                            prefixIcon: const Icon(Icons.payments_outlined)),
                        validator: (value) {
                          final parsed = double.tryParse(value ?? '');
                          if (parsed == null || parsed <= 0) {
                            return tr(ref, 'Enter a price greater than 0.',
                                'กรุณากรอกราคามากกว่า 0');
                          }
                          if (parsed > 1000000) {
                            return tr(
                                ref,
                                'Price cannot be over \u0E3F1,000,000.',
                                'ราคาต้องไม่เกิน \u0E3F1,000,000');
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
                        decoration: InputDecoration(
                            labelText:
                                tr(ref, 'Stock quantity', 'จำนวนคงเหลือ'),
                            prefixIcon: const Icon(Icons.inventory_2_outlined)),
                        validator: (value) {
                          final parsed = int.tryParse(value ?? '');
                          if (parsed == null) {
                            return tr(ref, 'Enter available stock.',
                                'กรุณากรอกจำนวนคงเหลือ');
                          }
                          if (parsed > 99) {
                            return tr(ref, 'Stock cannot be over 99.',
                                'จำนวนคงเหลือต้องไม่เกิน 99');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: category,
                        items: categories
                            .map((c) => DropdownMenuItem(
                                value: c, child: Text(categoryLabel(ref, c))))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => category = v ?? category),
                        decoration: InputDecoration(
                            labelText: tr(ref, 'Category', 'หมวดหมู่'),
                            prefixIcon: const Icon(Icons.category_outlined)),
                      ),
                      const SizedBox(height: 18),
                      Text(tr(ref, 'Product images', 'รูปสินค้า'),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      if (images.isEmpty)
                        AppEmptyState(
                          icon: Icons.add_photo_alternate_outlined,
                          title: tr(ref, 'Add at least one image',
                              'เพิ่มรูปสินค้าอย่างน้อย 1 รูป'),
                          message: tr(
                              ref,
                              'Choose a product photo from your gallery or take one with the camera.',
                              'เลือกรูปจากแกลเลอรีหรือถ่ายด้วยกล้อง'),
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
                                  label: Text(tr(ref, 'Gallery', 'แกลเลอรี')))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: OutlinedButton.icon(
                                  onPressed: () =>
                                      pickImage(ImageSource.camera),
                                  icon: const Icon(Icons.photo_camera_outlined),
                                  label: Text(tr(ref, 'Camera', 'กล้อง')))),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: saving ? null : save,
                        child: Text(saving
                            ? tr(ref, 'Saving...', 'กำลังบันทึก...')
                            : tr(ref, 'Save product', 'บันทึกสินค้า')),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(ref, 'Add at least one product image.',
              'กรุณาเพิ่มรูปสินค้าอย่างน้อย 1 รูป'))));
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
      refreshSeller(ref, productId: widget.productId);
      if (mounted) goBack(context, fallback: '/seller');
    } on DioException catch (error) {
      if (mounted) {
        final message = error.response?.data['error']?.toString() ??
            tr(ref, 'Unable to save product. Please check the product details.',
                'ไม่สามารถบันทึกสินค้าได้ กรุณาตรวจสอบข้อมูลสินค้า');
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
    final text = newValue.text.replaceAll(_notPriceChars, '');
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
