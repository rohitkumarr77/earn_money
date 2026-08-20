import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedWheel extends StatelessWidget {
  final AnimationController controller;
  final List<int> values;
  final List<Color> colors;

  const AnimatedWheel({
    super.key,
    required this.controller,
    required this.values,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow effect
        AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            return Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6366F1).withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            );
          },
        ),
        // Wheel
        AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            return Transform.rotate(
              angle: controller.value * 5 * 2 * math.pi,
              child: child,
            );
          },
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Stack(
              children: [
                CustomPaint(
                  size: const Size(320, 320),
                  painter: WheelPainter(
                    segments: values.length,
                    colors: colors,
                    values: values,
                  ),
                ),
                // Border ring
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF334155),
                      width: 12,
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF475569),
                      width: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Center button
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF6366F1),
                Color(0xFFEC4899),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF1E293B),
            ),
            child: Container(
              margin: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6366F1),
                    Color(0xFFEC4899),
                  ],
                ),
              ),
              child: const Center(
                child: Text(
                  '🎯',
                  style: TextStyle(fontSize: 32),
                ),
              ),
            ),
          ),
        ),
        // Pointer
        Positioned(
          top: 0,
          child: Container(
            width: 30,
            height: 40,
            child: CustomPaint(
              painter: PointerPainter(),
            ),
          ),
        ),
      ],
    );
  }
}

class WheelPainter extends CustomPainter {
  final int segments;
  final List<Color> colors;
  final List<int> values;

  WheelPainter({
    required this.segments,
    required this.colors,
    required this.values,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segmentAngle = 2 * math.pi / segments;

    for (int i = 0; i < segments; i++) {
      final startAngle = i * segmentAngle - math.pi / 2;
      final sweepAngle = segmentAngle;

      // Draw segment
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            colors[i % colors.length],
            colors[i % colors.length].withOpacity(0.7),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Draw separator line
      final linePaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      final lineStart = Offset(
        center.dx + (radius * 0.3) * math.cos(startAngle),
        center.dy + (radius * 0.3) * math.sin(startAngle),
      );
      final lineEnd = Offset(
        center.dx + radius * math.cos(startAngle),
        center.dy + radius * math.sin(startAngle),
      );

      canvas.drawLine(lineStart, lineEnd, linePaint);

      // Draw value text
      final textAngle = startAngle + (segmentAngle / 2);
      final textRadius = radius * 0.65;
      final textPosition = Offset(
        center.dx + textRadius * math.cos(textAngle),
        center.dy + textRadius * math.sin(textAngle),
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: values[i].toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            shadows: [
              Shadow(
                color: Colors.black26,
                offset: Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      canvas.save();
      canvas.translate(textPosition.dx, textPosition.dy);
      canvas.rotate(textAngle + math.pi / 2);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}