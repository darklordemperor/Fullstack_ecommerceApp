import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/widget/app_ui.dart';
import '../model/product_model.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.onTap});

  final ProductModel product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AppProductImage(
                      image: product.mainImage,
                      semanticLabel: product.name,
                    ),
                  ),
                  Positioned(
                    left: AppSpace.sm,
                    top: AppSpace.sm,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        // Surface-toned (not hardcoded white) so the badge stays
                        // legible over the image in both light and dark themes.
                        color: colors.surface.withValues(alpha: .92),
                        borderRadius: AppRadius.brPill,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.md, vertical: AppSpace.xs),
                        child: Text(
                          product.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  AppSpace.gapSm,
                  Text(
                    NumberFormat.currency(locale: 'th_TH', symbol: '฿')
                        .format(product.price),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  AppSpace.gapXs,
                  Row(
                    children: [
                      Icon(Icons.storefront_rounded,
                          size: AppIconSize.sm, color: colors.onSurfaceVariant),
                      AppSpace.gapXs,
                      Expanded(
                        child: Text(product.sellerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
