import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../settings/app_settings.dart';
import '../theme/app_dimens.dart';

class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.fallback = '/home'});

  final String fallback;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppLanguage.text('Back', 'ย้อนกลับ'),
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => goBack(context, fallback: fallback),
    );
  }
}

void goBack(BuildContext context, {String fallback = '/home'}) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.cloud_off_outlined,
      title: AppLanguage.text(
          'Unable to load this right now', 'ไม่สามารถโหลดข้อมูลได้'),
      message: message,
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(AppLanguage.text('Try again', 'ลองอีกครั้ง'))),
    );
  }
}

class AppSegmentedTabBar extends StatelessWidget
    implements PreferredSizeWidget {
  const AppSegmentedTabBar({
    super.key,
    required this.tabs,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 12),
  });

  final List<Widget> tabs;
  final EdgeInsetsGeometry padding;

  @override
  Size get preferredSize => const Size.fromHeight(62);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: AppRadius.brLg,
          border: Border.all(color: colors.outlineVariant),
        ),
        child: TabBar(
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: colors.onSurface,
          unselectedLabelColor: colors.onSurfaceVariant,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          indicator: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadius.brSm,
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppSpace.xs),
          tabs: tabs,
        ),
      ),
    );
  }
}

class AppInfoPanel extends StatelessWidget {
  const AppInfoPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.brXl,
        border: Border.all(color: colors.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F111827),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

String friendlyError(Object error) {
  debugPrint('App error: $error');
  final text = error.toString().toLowerCase();
  if (text.contains('401') || text.contains('unauthorized')) {
    return AppLanguage.text('Please sign in again to continue.',
        'กรุณาเข้าสู่ระบบอีกครั้งเพื่อดำเนินการต่อ');
  }
  if (text.contains('socket') ||
      text.contains('connection') ||
      text.contains('dioexception')) {
    return AppLanguage.text(
        'Please check that the backend is running and your device has a connection.',
        'กรุณาตรวจสอบว่า backend กำลังทำงานและอุปกรณ์เชื่อมต่อเครือข่ายอยู่');
  }
  return AppLanguage.text('Something went wrong. Please try again.',
      'เกิดข้อผิดพลาด กรุณาลองอีกครั้ง');
}

class AppProductImage extends StatelessWidget {
  const AppProductImage({
    super.key,
    required this.image,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.semanticLabel,
  });

  final String image;
  final BoxFit fit;
  final double? width;
  final double? height;

  /// Accessibility label announced for this image (e.g. the product name).
  /// When null/empty the image is treated as decorative.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final child = _resolveImage();
    if (semanticLabel == null || semanticLabel!.isEmpty) return child;
    return Semantics(label: semanticLabel, image: true, child: child);
  }

  Widget _resolveImage() {
    if (image.startsWith('data:image')) {
      final commaIndex = image.indexOf(',');
      if (commaIndex != -1) {
        try {
          final bytes = base64Decode(image.substring(commaIndex + 1));
          return Image.memory(bytes,
              width: width,
              height: height,
              fit: fit,
              gaplessPlayback: true,
              cacheWidth: width == null ? null : (width! * 2).round(),
              errorBuilder: (_, __, ___) => const _ImageFallback());
        } catch (error) {
          debugPrint('Image decode failed: $error');
        }
      }
    }

    if (image.startsWith('http://') || image.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: image,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: width == null ? null : (width! * 2).round(),
        fadeInDuration: Duration.zero,
        errorWidget: (_, __, ___) => const _ImageFallback(),
      );
    }

    return const _ImageFallback();
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(Icons.image_not_supported_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

Future<bool> ensureImagePermission(
    BuildContext context, ImageSource source) async {
  try {
    final permission =
        source == ImageSource.camera ? Permission.camera : Permission.photos;
    var status = await permission.status;
    if (!status.isGranted && !status.isLimited) {
      status = await permission.request();
    }
    if ((status.isDenied || status.isPermanentlyDenied) &&
        source == ImageSource.gallery) {
      final storageStatus = await Permission.storage.request();
      status = storageStatus;
    }
    final allowed = status.isGranted || status.isLimited;
    if (!allowed && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(source == ImageSource.camera
              ? AppLanguage.text(
                  'Camera permission is required to take a photo.',
                  'ต้องอนุญาตใช้กล้องเพื่อถ่ายรูป')
              : AppLanguage.text(
                  'Photo permission is required to choose an image.',
                  'ต้องอนุญาตเข้าถึงรูปภาพเพื่อเลือกรูป')),
          action: SnackBarAction(
              label: AppLanguage.text('Settings', 'ตั้งค่า'),
              onPressed: openAppSettings),
        ),
      );
    }
    return allowed;
  } on MissingPluginException catch (error) {
    debugPrint('Permission plugin unavailable, continuing to picker: $error');
    return true;
  }
}
