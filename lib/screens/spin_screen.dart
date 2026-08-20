import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../services/ad_service.dart';
import '../services/firestore_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_wheel.dart';
import '../widgets/gradient_button.dart';
import '../widgets/stats_badge.dart';
import '../widgets/result_card.dart';

class SpinScreen extends StatefulWidget {
  const SpinScreen({super.key});

  @override
  State<SpinScreen> createState() => _SpinScreenState();
}

class _SpinScreenState extends State<SpinScreen> with TickerProviderStateMixin {
  static const List<int> _rewards = FirestoreService.spinRewards;
  late List<int> _segments;

  late AnimationController _glowController;
  late AnimationController _fadeController;
  late ConfettiController _confettiController;

  double _rotationTurns = 0;
  int? _lastWinAmount;
  bool _isSpinning = false;
  bool _spinCheckDone = false;

  final int _maxSpins = 5;

  final List<Color> _wheelColors = [
    const Color(0xFF3B82F6),
    const Color(0xFF6366F1),
    const Color(0xFF8B5CF6),
    const Color(0xFFEC4899),
    const Color(0xFFF59E0B),
    const Color(0xFF10B981),
    const Color(0xFF14B8A6),
    const Color(0xFF06B6D4),
  ];

  @override
  void initState() {
    super.initState();
    _segments = List.generate(8, (i) => _rewards[i % _rewards.length]);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSpinsResetIfNewDay());
  }

  Future<void> _ensureSpinsResetIfNewDay() async {
    if (_spinCheckDone) return;
    final uid = context.read<UserProvider>().firebaseUser?.uid;
    if (uid == null) return;
    final firestore = context.read<FirestoreService>();
    await firestore.ensureSpinsResetIfNewDay(uid);
    if (mounted) _spinCheckDone = true;
  }

  @override
  void dispose() {
    _glowController.dispose();
    _fadeController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _spinWheel(UserModel? user) async {
    final uid = context.read<UserProvider>().firebaseUser?.uid;
    final adService = context.read<AdService>();
    final firestore = context.read<FirestoreService>();

    if (uid == null || user == null) return;

    final remainingSpins = _maxSpins - (user.spinsToday).clamp(0, _maxSpins);
    if (remainingSpins <= 0 || _isSpinning) return;

    setState(() {
      _isSpinning = true;
      _lastWinAmount = null;
    });

    // Show rewarded ad first
    final earned = await adService.showRewardedAd();
    if (!earned && mounted) {
      setState(() => _isSpinning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please watch the ad to spin. If the ad didn''t load, wait a moment and try again.'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    // Calculate winning segment
    final random = math.Random();
    final segmentAngle = 2 * math.pi / _segments.length;
    final winningIndex = random.nextInt(_segments.length);
    final offset = winningIndex * segmentAngle + segmentAngle / 2 + random.nextDouble() * segmentAngle * 0.5;
    const extraTurns = 5.0;
    final targetTurns = _rotationTurns + extraTurns + offset / (2 * math.pi);

    // Animate wheel rotation
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    final curve = CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);
    final anim = Tween<double>(begin: _rotationTurns, end: targetTurns).animate(curve);

    anim.addListener(() {
      if (mounted) setState(() => _rotationTurns = anim.value);
    });

    await controller.forward();
    controller.dispose();

    // Perform spin in Firestore
    final reward = await firestore.performSpin(uid);

    if (mounted) {
      setState(() {
        _isSpinning = false;
        if (reward > 0) _lastWinAmount = reward;
      });

      if (reward > 0) {
        _fadeController.forward(from: 0);
        _confettiController.play();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 +$reward points added!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No spins left today. Try again tomorrow.'),
            backgroundColor: const Color(0xFFF59E0B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final adService = context.watch<AdService>();
    final totalPoints = user?.points ?? 0;
    final spinsUsed = (user?.spinsToday ?? 0).clamp(0, _maxSpins);
    final remainingSpins = _maxSpins - spinsUsed;
    final canSpin = remainingSpins > 0 && !_isSpinning && adService.isRewardedAdLoaded;

    return RefreshIndicator(
      onRefresh: _ensureSpinsResetIfNewDay,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: _buildAppBar(totalPoints),
        body: Stack(
          children: [
            _buildBackground(),
            _buildContent(user, adService, remainingSpins, canSpin),
            _buildConfetti(),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(int totalPoints) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
        ).createShader(bounds),
        child: const Text(
          'SPIN',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
      ),
      // actions: [
      //   StatsBadge(
      //     icon: Icons.stars_rounded,
      //     value: totalPoints.toString(),
      //   ),
      //   const SizedBox(width: 8),
      //   const StatsBadge(
      //     icon: Icons.person_rounded,
      //     value: 'Level 5',
      //   ),
      //   const SizedBox(width: 16),
      // ],
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -100,
            left: -100,
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                return Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color(0xFF6366F1).withOpacity(
                          0.15 * (1 - _glowController.value),
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: -150,
            right: -150,
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                return Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color(0xFFEC4899).withOpacity(
                          0.1 * _glowController.value,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(UserModel? user, AdService adService, int remainingSpins, bool canSpin) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildTitle(),
            const SizedBox(height: 30),
            _buildProgressBar(remainingSpins),
            const SizedBox(height: 40),
            _buildWheel(),
            const SizedBox(height: 40),
            if (_lastWinAmount != null) _buildResult(),
            const SizedBox(height: 20),
            _buildSpinsInfo(remainingSpins, adService),
            const SizedBox(height: 30),
            _buildSpinButton(canSpin, adService, user),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: Column(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                  ).createShader(bounds),
                  child: Text(
                    'Spin & Earn',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Watch ads and win rewards',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressBar(int remainingSpins) {
    final progress = (_maxSpins - remainingSpins) / _maxSpins;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daily Progress',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  color: Color(0xFF6366F1),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: progress),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: const Color(0xFF334155),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF6366F1),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWheel() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.8 + (0.2 * value),
            child: child,
          ),
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow effect
          AnimatedBuilder(
            animation: _glowController,
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
          // Wheel - using rotation value from state
          Transform.rotate(
            angle: _rotationTurns * 2 * math.pi,
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
                      segments: _segments.length,
                      colors: _wheelColors,
                      values: _segments,
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
      ),
    );
  }

  Widget _buildResult() {
    return FadeTransition(
      opacity: _fadeController,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.5, end: 1.0).animate(
          CurvedAnimation(
            parent: _fadeController,
            curve: Curves.easeOutBack,
          ),
        ),
        // child: ResultCard(amount: _lastWinAmount!),
      ),
    );
  }

  Widget _buildSpinsInfo(int remainingSpins, AdService adService) {
    return GlassCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(seconds: 2),
                builder: (context, value, child) {
                  return Transform.rotate(
                    angle: value * 2 * math.pi,
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF6366F1).withOpacity(0.2),
                        const Color(0xFFEC4899).withOpacity(0.2),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: Color(0xFF6366F1),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Spins remaining:',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$remainingSpins/$_maxSpins',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (!adService.isRewardedAdLoaded && remainingSpins > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Loading ad...',
                    style: TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpinButton(bool canSpin, AdService adService, UserModel? user) {
    String buttonText = 'SPIN NOW (WATCH AD)';
    if (_isSpinning) {
      buttonText = 'SPINNING...';
    } else if (!adService.isRewardedAdLoaded) {
      buttonText = 'LOADING AD...';
    }

    return GradientButton(
      onPressed: canSpin ? () => _spinWheel(user) : null,
      text: buttonText,
      icon: Icons.play_circle_outline_rounded,
      isLoading: _isSpinning,
    );
  }

  Widget _buildConfetti() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConfettiWidget(
        confettiController: _confettiController,
        blastDirection: math.pi / 2,
        blastDirectionality: BlastDirectionality.explosive,
        emissionFrequency: 0.05,
        numberOfParticles: 30,
        maxBlastForce: 20,
        minBlastForce: 5,
        gravity: 0.3,
        colors: const [
          Color(0xFF6366F1),
          Color(0xFFEC4899),
          Color(0xFFF59E0B),
          Color(0xFF10B981),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.95),
        border: const Border(
          top: BorderSide(
            color: Color(0xFF334155),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            // children: [
            //   _buildNavItem(Icons.casino_rounded, 'Spin', true),
            //   _buildNavItem(Icons.account_balance_wallet_rounded, 'Wallet', false),
            //   _buildNavItem(Icons.person_rounded, 'Profile', false),
            // ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          )
              : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : const Color(0xFF64748B),
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF64748B),
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// Wheel Painter
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

// Pointer Painter
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