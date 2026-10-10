import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Sanchalan monogram (a diya, the lamp lit at celebrations) with an optional
/// wordmark. Drawn in code so it needs no asset; replace with the real logo
/// when there is one.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 72, this.wordmark = false, this.wordmarkColor});

  final double size;
  final bool wordmark;
  final Color? wordmarkColor;

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: _DiyaPainter()),
    );
    return Semantics(
      label: 'Sanchalan',
      image: true,
      child: ExcludeSemantics(
        child: wordmark
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  mark,
                  SizedBox(height: size * 0.18),
                  Text(
                    'Sanchalan',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontFamily: AppFonts.display,
                          color: wordmarkColor ?? AppColors.maroon,
                          fontSize: size * 0.42,
                          height: 1.1,
                        ),
                  ),
                ],
              )
            : mark,
      ),
    );
  }
}

class _DiyaPainter extends CustomPainter {
  const _DiyaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.save();
    canvas.scale(s);

    // Badge
    final badge = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 100, 100),
      const Radius.circular(28),
    );
    canvas.drawRRect(
      badge,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.maroon],
        ).createShader(const Rect.fromLTWH(0, 0, 100, 100)),
    );

    // Flame
    final flame = Path()
      ..moveTo(50, 14)
      ..cubicTo(64, 31, 64, 45, 50, 52)
      ..cubicTo(36, 45, 36, 31, 50, 14)
      ..close();
    canvas.drawPath(
      flame,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.goldContainer, AppColors.gold],
        ).createShader(const Rect.fromLTWH(36, 14, 28, 38)),
    );

    // Lamp bowl
    final bowl = Path()
      ..moveTo(22, 58)
      ..lineTo(78, 58)
      ..cubicTo(78, 77, 64, 86, 50, 86)
      ..cubicTo(36, 86, 22, 77, 22, 58)
      ..close();
    canvas.drawPath(bowl, Paint()..color = Colors.white);

    // Rim highlight
    canvas.drawLine(
      const Offset(22, 58),
      const Offset(78, 58),
      Paint()
        ..color = AppColors.goldContainer
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
