import 'dart:math' as math;

import 'package:archbtw_sh/global/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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
  late final Ticker _ticker;
  final ValueNotifier<int> _frameNotifier = ValueNotifier<int>(0);
  late final List<_Snowflake> _flakes;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(42);
    _flakes = List.generate(
      widget.flakeCount,
      (i) => _Snowflake.random(rng, index: i),
    );
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final double dt = _lastElapsed == Duration.zero
        ? 0.016
        : ((elapsed - _lastElapsed).inMicroseconds / 1000000.0).clamp(
            0.0,
            0.05,
          );
    _lastElapsed = elapsed;

    for (int i = 0; i < _flakes.length; i++) {
      _flakes[i].update(dt);
    }
    _frameNotifier.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frameNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _SnowPainter(
            flakes: _flakes,
            repaint: _frameNotifier,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

enum _FlakeShape { circle, star, plus }

class _Snowflake {
  double x; // Normalized 0..1
  double y; // Normalized 0..1
  final double radius;
  final double speedY;
  final double driftAmplitude;
  final double driftFrequency;
  double phase;
  final _FlakeShape shape;
  final Color precomputedColor;

  _Snowflake({
    required this.x,
    required this.y,
    required this.radius,
    required this.speedY,
    required this.driftAmplitude,
    required this.driftFrequency,
    required this.phase,
    required this.shape,
    required this.precomputedColor,
  });

  factory _Snowflake.random(math.Random rng, {required int index}) {
    final _FlakeShape shape;
    if (index % 8 == 0) {
      shape = _FlakeShape.star;
    } else if (index % 12 == 0) {
      shape = _FlakeShape.plus;
    } else {
      shape = _FlakeShape.circle;
    }

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

    final double opacity = 0.14 + rng.nextDouble() * 0.26;

    return _Snowflake(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      radius: 1.2 + rng.nextDouble() * 2.0,
      speedY: 0.025 + rng.nextDouble() * 0.045,
      driftAmplitude: 0.0003 + rng.nextDouble() * 0.0007,
      driftFrequency: 0.7 + rng.nextDouble() * 1.6,
      phase: rng.nextDouble() * math.pi * 2,
      shape: shape,
      precomputedColor: tint.withValues(alpha: opacity),
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
  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1
    ..strokeCap = StrokeCap.round;

  _SnowPainter({
    required this.flakes,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Scale active flake count on smaller mobile viewports so density stays even
    // and low-end mobile GPUs do less work per frame.
    final int activeCount = size.width < 600
        ? (flakes.length * 0.62).round()
        : flakes.length;

    for (int i = 0; i < activeCount; i++) {
      final flake = flakes[i];
      final double dx = flake.x * size.width;
      final double dy = flake.y * size.height;

      switch (flake.shape) {
        case _FlakeShape.circle:
          _fillPaint.color = flake.precomputedColor;
          canvas.drawCircle(Offset(dx, dy), flake.radius, _fillPaint);
        case _FlakeShape.plus:
          _strokePaint.color = flake.precomputedColor;
          final double r = flake.radius * 1.7;
          canvas.drawLine(Offset(dx - r, dy), Offset(dx + r, dy), _strokePaint);
          canvas.drawLine(Offset(dx, dy - r), Offset(dx, dy + r), _strokePaint);
        case _FlakeShape.star:
          _strokePaint.color = flake.precomputedColor;
          final double r = flake.radius * 1.85;
          final double d = r * 0.7;
          canvas.drawLine(Offset(dx - r, dy), Offset(dx + r, dy), _strokePaint);
          canvas.drawLine(Offset(dx, dy - r), Offset(dx, dy + r), _strokePaint);
          canvas.drawLine(
            Offset(dx - d, dy - d),
            Offset(dx + d, dy + d),
            _strokePaint,
          );
          canvas.drawLine(
            Offset(dx - d, dy + d),
            Offset(dx + d, dy - d),
            _strokePaint,
          );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SnowPainter oldDelegate) => false;
}
