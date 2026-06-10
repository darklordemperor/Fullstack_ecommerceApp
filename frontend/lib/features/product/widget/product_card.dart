import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../model/product_model.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.onTap});
  final ProductModel product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: CachedNetworkImage(imageUrl: product.mainImage, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported)),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(NumberFormat.currency(locale: 'th_TH', symbol: '฿').format(product.price), style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  Text(product.sellerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.subtext, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
