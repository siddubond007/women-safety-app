import 'package:flutter/material.dart';

import '../../core/theme/sakhi_design_system.dart';

class SakhiPageIndicator extends StatelessWidget {
  const SakhiPageIndicator({
    super.key,
    required this.currentPage,
    required this.onSelected,
    this.count = 3,
  });

  final int currentPage;
  final ValueChanged<int> onSelected;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final selected = currentPage == index;
        return Semantics(
          button: true,
          selected: selected,
          label: 'Select onboarding page',
          child: InkWell(
            key: Key('onboarding-dot-$index'),
            borderRadius: BorderRadius.circular(SakhiRadii.pill),
            onTap: () => onSelected(index),
            child: SizedBox(
              width: 30,
              height: 30,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: selected ? 28 : 9,
                  height: 7,
                  decoration: BoxDecoration(
                    color: selected
                        ? SakhiColors.purple
                        : SakhiColors.progressInactive,
                    borderRadius: BorderRadius.circular(SakhiRadii.pill),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
