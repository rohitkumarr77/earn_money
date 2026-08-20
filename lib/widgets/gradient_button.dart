import 'package:flutter/material.dart';

class GradientButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String text;
  final IconData icon;
  final bool isLoading;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.text,
    required this.icon,
    this.isLoading = false,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed != null
          ? (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      }
          : null,
      onTapUp: widget.onPressed != null
          ? (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        widget.onPressed!();
      }
          : null,
      onTapCancel: widget.onPressed != null
          ? () {
        setState(() => _isPressed = false);
        _controller.reverse();
      }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, _isPressed ? 2 : 0, 0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: widget.onPressed != null
                ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF6366F1),
                Color(0xFFEC4899),
              ],
            )
                : LinearGradient(
              colors: [
                const Color(0xFF6366F1).withOpacity(0.5),
                const Color(0xFFEC4899).withOpacity(0.5),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: widget.onPressed != null && !_isPressed
                ? [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              else
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(seconds: 2),
                  builder: (context, value, child) {
                    return Transform.rotate(
                      angle: value * 6.28,
                      child: child,
                    );
                  },
                  child: Icon(
                    widget.icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              const SizedBox(width: 12),
              Text(
                widget.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}