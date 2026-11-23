import 'package:flutter/material.dart';

import '../assets/app_assets.dart';
import '../theme/app_colors.dart';
import '../../features/auth/backend_api_client.dart';

/// Loads a protected Sakhi media URL with the active session's bearer token.
/// Supports both fixed dimensions and Instagram-style intrinsic aspect-ratio
/// rendering (`fit: BoxFit.fitWidth` or `BoxFit.contain`) so portrait, square,
/// and landscape posts never clip the top or bottom of uploaded photos.
class SakhiRemoteMediaImage extends StatelessWidget {
  final String source;
  final BoxFit fit;
  final double? width;
  final double? height;
  final ImageErrorWidgetBuilder? errorBuilder;

  const SakhiRemoteMediaImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorBuilder,
  });

  Widget _fallback(BuildContext context, Object error, StackTrace? stack) {
    if (errorBuilder != null) return errorBuilder!(context, error, stack);
    return Container(
      width: width ?? double.infinity,
      height: height ?? 220,
      color: AppColors.pastelPink,
      alignment: Alignment.center,
      child: const Icon(
        Icons.broken_image_outlined,
        color: AppColors.primaryPurple,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: BackendApiClient.imageRequestHeaders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            width: width ?? double.infinity,
            height: height ?? 240,
            color: AppColors.pastelPink.withValues(alpha: 0.45),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: AppColors.primaryPurple,
              ),
            ),
          );
        }
        final headers = snapshot.data ?? const <String, String>{};
        if (headers.isEmpty) {
          return _fallback(
            context,
            StateError('Sign in to view this media.'),
            null,
          );
        }
        return Image.network(
          AppAssets.resolveRemoteMediaUrl(source),
          headers: headers,
          width: width,
          height: height,
          fit: fit,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: width ?? double.infinity,
              height: height ?? 240,
              color: AppColors.pastelPink.withValues(alpha: 0.35),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.primaryPurple,
                ),
              ),
            );
          },
          errorBuilder: _fallback,
        );
      },
    );
  }
}
