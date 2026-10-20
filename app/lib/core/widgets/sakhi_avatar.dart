import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../shared/widgets/sakhi_crisp_art.dart';
import '../assets/app_assets.dart';
import '../theme/app_colors.dart';
import 'sakhi_remote_media_image.dart';

/// Circular user avatar with optional camera edit button, distinct local
/// women's illustrated portraits (`assets/images/profile/avatar_*.webp`),
/// and remote backend media URL support (`http://`, `https://`, or `/api/v1/`).
class SakhiAvatar extends StatelessWidget {
  final String imageAsset;
  final String? fallbackLabel;
  final Uint8List? memoryBytes;
  final double size;
  final bool showEditCameraBadge;
  final VoidCallback? onCameraTap;
  final double borderWidth;

  const SakhiAvatar({
    super.key,
    required this.imageAsset,
    this.fallbackLabel,
    this.memoryBytes,
    this.size = 44,
    this.showEditCameraBadge = false,
    this.onCameraTap,
    this.borderWidth = 2.0,
  });

  bool get _isNetworkUrl {
    final trimmed = imageAsset.trim();
    return trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('/api/v1/');
  }

  @override
  Widget build(BuildContext context) {
    final hasLocalPhoto = imageAsset.trim().isNotEmpty;
    final effectiveKey = imageAsset.trim();
    final localAvatarAsset = hasLocalPhoto
        ? AppAssets.forKey(effectiveKey)
        : '';
    final crispFallback = hasLocalPhoto
        ? SakhiCrispAvatarArt(assetOrUrl: localAvatarAsset, size: size)
        : Container(
            color: AppColors.pastelLavender,
            alignment: Alignment.center,
            child: Icon(
              Icons.person_outline_rounded,
              color: AppColors.primaryPurple,
              size: size * 0.55,
            ),
          );

    Widget avatarContent;
    if (memoryBytes != null && memoryBytes!.isNotEmpty) {
      avatarContent = Image.memory(
        memoryBytes!,
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    } else if (_isNetworkUrl) {
      avatarContent = SakhiRemoteMediaImage(
        source: imageAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: AppColors.pastelPink,
          alignment: Alignment.center,
          child: Tooltip(
            message: 'Uploaded photo unavailable',
            child: Icon(
              Icons.broken_image_outlined,
              color: AppColors.primaryPurple,
              size: size * 0.42,
            ),
          ),
        ),
      );
    } else if (hasLocalPhoto) {
      avatarContent = Image.asset(
        localAvatarAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
        errorBuilder: (_, _, _) => crispFallback,
      );
    } else {
      avatarContent = crispFallback;
    }

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
          child: ClipOval(child: avatarContent),
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
