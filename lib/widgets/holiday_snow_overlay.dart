import 'dart:math' as math;

import 'package:archbtw_sh/global/colors.dart';
import 'package:flutter/material.dart';

class HolidaySnowOverlay extends StatefulWidget {
  final int flakeCount;

  const HolidaySnowOverlay({
    super.key,
    this.flakeCount = 95,
  });

  @override
  State<HolidaySnowOverlay> createState() => _HolidaySnowOverlayState();
}

class _HolidaySnowOverlayState extends State<HolidaySnowOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Snowflake> _flakes;
  DateTime? _lastTick;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(42);
    _flakes = List.generate(
      widget.flakeCount,
      (i) => _Snowflake.random(rng, index: i),
    );
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )
      ..addListener(_onTick)
      ..repeat();
  }

  void _onTick() {
    final now = DateTime.now();
    final dt = _lastTick == null
        ? 0.016
        : (now.difference(_lastTick!).inMicroseconds / 1000000.0).clamp(
            0.0,
            0.05,
          );
    _lastTick = now;

    for (final flake in _flakes) {
      flake.update(dt);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _SnowPainter(
            flakes: _flakes,
            repaint: _controller,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Snowflake {
  double x; // Normalized 0..1
  double y; // Normalized 0..1
  final double radius;
  final double speedY;
  final double driftAmplitude;
  final double driftFrequency;
  double phase;
  final double opacity;
  final String? glyph;
  final Color tint;

  _Snowflake({
    required this.x,
    required this.y,
    required this.radius,
    required this.speedY,
    required this.driftAmplitude,
    required this.driftFrequency,
    required this.phase,
    required this.opacity,
    required this.glyph,
    required this.tint,
  });

  factory _Snowflake.random(math.Random rng, {required int index}) {
    // Mix of soft snow particles and terminal ASCII snowflakes ('*', '+', '·')
    final bool isAscii = index % 4 == 0;
    final String? glyph = isAscii
        ? (index % 8 == 0
            ? '*'
            : (index % 12 == 0 ? '+' : '·'))
        : null;

    // Subtle tint: mostly white/ice, with occasional faint holiday gold or purple
    final Color tint;
    if (index % 9 == 0) {
      tint = kHolidayIce;
    } else if (index % 17 == 0) {
      tint = kHolidayGold;
    } else if (index % 23 == 0) {
      tint = kAccentColor;
    } else {
      tint = Colors.white;
    }

    return _Snowflake(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      radius: 1.2 + rng.nextDouble() * 2.1,
      speedY: 0.025 + rng.nextDouble() * 0.045,
      driftAmplitude: 0.0003 + rng.nextDouble() * 0.0007,
      driftFrequency: 0.7 + rng.nextDouble() * 1.6,
      phase: rng.nextDouble() * math.pi * 2,
      opacity: 0.14 + rng.nextDouble() * 0.26,
      glyph: glyph,
      tint: tint,
    );
  }

  void update(double dt) {
    phase += driftFrequency * dt;
    y += speedY * dt;
    x += math.sin(phase) * driftAmplitude;

    if (y > 1.04) {
      y = -0.04;
      x = (x + 0.13) % 1.0;
    }
    if (x < -0.02) x += 1.04;
    if (x > 1.02) x -= 1.04;
  }
}

class _SnowPainter extends CustomPainter {
  final List<_Snowflake> flakes;

  _SnowPainter({
    required this.flakes,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final paint = Paint()..style = PaintingStyle.fill;

    for (final flake in flakes) {
      final dx = flake.x * size.width;
      final dy = flake.y * size.height;
      final color = flake.tint.withValues(alpha: flake.opacity);

      if (flake.glyph != null) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: flake.glyph,
            style: TextStyle(
              color: color,
              fontSize: flake.radius * 6.0,
              fontFamily: 'JetBrainsMono',
              fontWeight: FontWeight.w400,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(dx - textPainter.width / 2, dy - textPainter.height / 2),
        );
      } else {
        paint.color = color;
        canvas.drawCircle(Offset(dx, dy), flake.radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SnowPainter oldDelegate) => false;
}
