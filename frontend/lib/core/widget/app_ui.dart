import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.fallback = '/home'});

  final String fallback;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
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
      title: 'Unable to load this right now',
      message: message,
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again')),
    );
  }
}

String friendlyError(Object error) {
  debugPrint('App error: $error');
  final text = error.toString().toLowerCase();
  if (text.contains('401') || text.contains('unauthorized')) {
    return 'Please sign in again to continue.';
  }
  if (text.contains('socket') ||
      text.contains('connection') ||
      text.contains('dioexception')) {
    return 'Please check that the backend is running and your device has a connection.';
  }
  return 'Something went wrong. Please try again.';
}

class AppProductImage extends StatelessWidget {
  const AppProductImage({
    super.key,
    required this.image,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final String image;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
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
              ? 'Camera permission is required to take a photo.'
              : 'Photo permission is required to choose an image.'),
          action: const SnackBarAction(
              label: 'Settings', onPressed: openAppSettings),
        ),
      );
    }
    return allowed;
  } on MissingPluginException catch (error) {
    debugPrint('Permission plugin unavailable, continuing to picker: $error');
    return true;
  }
}
