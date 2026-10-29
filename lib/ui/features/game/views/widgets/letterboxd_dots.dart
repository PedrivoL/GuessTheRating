import 'package:flutter/material.dart';
import 'package:my_first_app/ui/core/theme/app_theme.dart';

/// Ícone decorativo com os três círculos nas cores clássicas do Letterboxd.
class LetterboxdDots extends StatelessWidget {
  const LetterboxdDots({super.key, this.dotSize = 12});

  final double dotSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(AppColors.letterboxdOrange),
        const SizedBox(width: 3),
        _dot(AppColors.letterboxdGreen),
        const SizedBox(width: 3),
        _dot(AppColors.letterboxdBlue),
      ],
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

