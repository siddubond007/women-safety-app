import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SakhiAvatar extends StatelessWidget {
  const SakhiAvatar({
    super.key,
    required this.imageAsset,
    this.size = 44,
    this.showEditCameraBadge = false,
    this.onCameraTap,
    this.borderWidth = 2,
    this.fallbackLabel,
  });

  final String imageAsset;
  final double size;
  final bool showEditCameraBadge;
  final VoidCallback? onCameraTap;
  final double borderWidth;
  final String? fallbackLabel;

  Widget _avatarImage() {
    if (imageAsset.trim().isEmpty) return _fallback();
    final isTrustedTransport = imageAsset.startsWith('https://');
    final image = isTrustedTransport
        ? Image.network(
            imageAsset,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => _fallback(),
          )
        : Image.asset(
            imageAsset,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => _fallback(),
          );
    return image;
  }

  Widget _fallback() => Center(
    child: Text(
      (fallbackLabel?.trim().isNotEmpty == true
          ? fallbackLabel!.trim().substring(0, 1)
          : 'S').toUpperCase(),
      style: TextStyle(
        fontSize: size * .38,
        fontWeight: FontWeight.w800,
        color: AppColors.primaryPurple,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
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
              BoxShadow(color: AppColors.primaryPurple.withValues(alpha: .10), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: ClipOval(
            child: _avatarImage(),
          ),
        ),
        if (showEditCameraBadge)
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: onCameraTap,
              child: Container(
                width: size * .30,
                height: size * .30,
                decoration: BoxDecoration(color: AppColors.primaryPurple, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: size * .16),
              ),
            ),
          ),
      ],
    );
  }
}
