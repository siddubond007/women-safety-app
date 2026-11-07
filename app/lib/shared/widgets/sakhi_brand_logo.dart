import 'package:flutter/material.dart';

import '../../core/branding/app_brand.dart';

class SakhiBrandLogo extends StatelessWidget {
  const SakhiBrandLogo({
    super.key,
    this.width = 148,
    this.height = 120,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: AppBrand.logoSemanticsLabel,
      child: Image.asset(
        AppBrand.logoAsset,
        key: const Key('sakhi-logo-lockup'),
        width: width,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
