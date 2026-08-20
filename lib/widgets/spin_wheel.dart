import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Wheel segments: 10, 25, 50, 100 points (repeated to fill).
class SpinWheel extends StatelessWidget {
  const SpinWheel({
    super.key,
    required this.segments,
    required this.rotationTurns,
    this.size = 220,
  });

  final List<int> segments;
  final double rotationTurns;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: rotationTurns * 2 * math.pi,
            child: CustomPaint(
              size: Size(size, size),
              painter: _WheelPainter(segments: segments),
            ),
          ),
          // Center pin
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.amber,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.brown, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
          ),
          // Pointer at top
          Positioned(
            top: 4,
            child: Icon(Icons.arrow_drop_down, size: 36, color: Colors.red.shade700),
          ),
        ],
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.segments});

  final List<int> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final sliceAngle = 2 * math.pi / segments.length;

    for (int i = 0; i < segments.length; i++) {
      final startAngle = i * sliceAngle - math.pi / 2;
      final paint = Paint()
        ..color = (i % 2 == 0) ? Colors.blue.shade400 : Colors.blue.shade700
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sliceAngle,
        true,
        paint,
      );
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sliceAngle,
        true,
        borderPaint,
      );

      // Text
      final textAngle = startAngle + sliceAngle / 2;
      final textRadius = radius * 0.65;
      final dx = center.dx + textRadius * math.cos(textAngle);
      final dy = center.dy + textRadius * math.sin(textAngle);
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${segments[i]}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(dx - textPainter.width / 2, dy - textPainter.height / 2);
      canvas.rotate(textAngle + math.pi / 2);
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }

    // Outer circle border
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.brown
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.segments != segments;
}
