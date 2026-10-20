import 'package:flutter/material.dart';

import '../assets/app_assets.dart';
import '../theme/app_colors.dart';
import '../../features/auth/backend_api_client.dart';

/// Loads a protected Sakhi media URL with the active session's bearer token.
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
      width: width,
      height: height,
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
            width: width,
            height: height,
            color: AppColors.pastelPink,
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
          errorBuilder: _fallback,
        );
      },
    );
  }
}
