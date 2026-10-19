import 'package:flutter/material.dart';
import '../../shared/widgets/sakhi_crisp_art.dart';
import '../theme/app_colors.dart';

/// Circular user avatar with optional camera edit button, infinite-DPI vector
/// portrait rendering for built-in test profiles, and automatic Cloud/Network
/// URL support (`http://` / `https://`).
class SakhiAvatar extends StatelessWidget {
  final String imageAsset;
  final double size;
  final bool showEditCameraBadge;
  final VoidCallback? onCameraTap;
  final double borderWidth;

  const SakhiAvatar({
    super.key,
    required this.imageAsset,
    this.size = 44,
    this.showEditCameraBadge = false,
    this.onCameraTap,
    this.borderWidth = 2.0,
  });

  bool get _isNetworkUrl =>
      imageAsset.startsWith('http://') || imageAsset.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    final crispFallback = SakhiCrispAvatarArt(
      assetOrUrl: imageAsset,
      size: size,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.pastelLavender,
            border: Border.all(color: Colors.white, width: borderWidth),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPurple.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipOval(
            child: _isNetworkUrl
                ? Image.network(
                    imageAsset,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    isAntiAlias: true,
                    errorBuilder: (_, _, _) => crispFallback,
                  )
                : crispFallback,
          ),
        ),
        if (showEditCameraBadge)
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: onCameraTap,
              child: Container(
                width: size * 0.30,
                height: size * 0.30,
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: size * 0.16,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
