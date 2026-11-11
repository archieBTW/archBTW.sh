import 'dart:async';
import 'dart:math' as math;

import 'package:archbtw_sh/global/colors.dart';
import 'package:archbtw_sh/widgets/nav_link.dart';
import 'package:flutter/material.dart';

class Header extends StatelessWidget {
  final int currentIndex;
  final Function(int) onItemTapped;

  const Header({
    super.key,
    required this.currentIndex,
    required this.onItemTapped,
  });

  static const double kTabletBreakpoint = 768.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= kTabletBreakpoint;

        final double titleFontSize = isDesktop ? 22 : 18;
        final double navLinkFontSize = isDesktop ? 16 : 14;

        final EdgeInsets padding = isDesktop
            ? const EdgeInsets.only(
                left: 48.0,
                right: 64.0,
                top: 16.0,
                bottom: 16.0,
              )
            : const EdgeInsets.only(
                left: 16.0,
                right: 28.0,
                top: 16.0,
                bottom: 16.0,
              );

        final headerContent = Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => onItemTapped(0),
              style: TextButton.styleFrom(
                splashFactory: NoSplash.splashFactory,
                overlayColor: Colors.transparent,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                alignment: Alignment.centerLeft,
              ),
              child: Text.rich(
                TextSpan(
                  style: TextStyle(
                    color: kTextColor,
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontFamily: 'JetBrainsMono',
                  ),
                  children: const [
                    TextSpan(
                      text: '// ',
                      style: TextStyle(color: kHolidayGreen),
                    ),
                    TextSpan(text: 'archBTW'),
                    TextSpan(
                      text: '.',
                      style: TextStyle(color: kHolidayRed),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: isDesktop ? 12.0 : 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  NavLink(
                    title: 'about',
                    index: 1,
                    currentIndex: currentIndex,
                    onTap: () => onItemTapped(1),
                    fontSize: navLinkFontSize,
                  ),
                  NavLink(
                    title: 'music',
                    index: 2,
                    currentIndex: currentIndex,
                    onTap: () => onItemTapped(2),
                    fontSize: navLinkFontSize,
                  ),
                  NavLink(
                    title: 'merch',
                    index: 3,
                    currentIndex: currentIndex,
                    onTap: () => onItemTapped(3),
                    fontSize: navLinkFontSize,
                  ),
                ],
              ),
            ),
          ],
        );
        return RepaintBoundary(
          child: Container(
            color: kBackgroundColor,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(padding: padding, child: headerContent),
                const HolidayStringLights(),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum HolidayLightsMode {
  solid('solid'),
  twinkle('twinkle'),
  chase('chase'),
  pulse('pulse'),
  off('off');

  final String label;
  const HolidayLightsMode(this.label);

  HolidayLightsMode get next {
    final nextIndex = (index + 1) % HolidayLightsMode.values.length;
    return HolidayLightsMode.values[nextIndex];
  }
}

class HolidayStringLights extends StatefulWidget {
  final HolidayLightsMode initialMode;

  const HolidayStringLights({
    super.key,
    this.initialMode = HolidayLightsMode.solid,
  });

  @override
  State<HolidayStringLights> createState() => HolidayStringLightsState();
}

class HolidayStringLightsState extends State<HolidayStringLights> {
  late HolidayLightsMode _mode;
  final ValueNotifier<double> _phaseNotifier = ValueNotifier<double>(0.0);
  Timer? _animationTimer;

  HolidayLightsMode get currentMode => _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _updateTimer();
  }

  void _updateTimer() {
    _animationTimer?.cancel();
    _animationTimer = null;
    if (_mode == HolidayLightsMode.solid || _mode == HolidayLightsMode.off) {
      _phaseNotifier.value = 0.0;
      return;
    }
    // Update animation at ~12.5 FPS (80ms) for low overhead
    _animationTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      _phaseNotifier.value = (_phaseNotifier.value + 0.16) % (math.pi * 2);
    });
  }

  void cycleMode() {
    setState(() {
      _mode = _mode.next;
      _updateTimer();
    });
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _phaseNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: const Key('holiday_string_lights'),
          behavior: HitTestBehavior.opaque,
          onTap: cycleMode,
          child: Tooltip(
            message: 'Holiday lights: ${_mode.label} (tap to change)',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: SizedBox(
                height: 22,
                width: double.infinity,
                child: CustomPaint(
                  painter: _StringLightsPainter(
                    phaseListenable: _phaseNotifier,
                    mode: _mode,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StringLightsPainter extends CustomPainter {
  final ValueNotifier<double> phaseListenable;
  final HolidayLightsMode mode;

  _StringLightsPainter({required this.phaseListenable, required this.mode})
    : super(repaint: phaseListenable);

  static const List<Color> _bulbColors = [
    kHolidayRed,
    kHolidayGreen,
    kHolidayGold,
    kAccentColor,
    kHolidayIce,
  ];

  // Precomputed C7 teardrop bulb contour so zero Paths are allocated per bulb.
  static final Path _bulbPath = _createBulbPath(5.6, 9.2);

  static Path _createBulbPath(double width, double height) {
    final double hw = width / 2;
    return Path()
      ..moveTo(-hw * 0.55, 0)
      ..cubicTo(-hw * 1.25, height * 0.28, -hw * 0.95, height * 0.72, 0, height)
      ..cubicTo(
        hw * 0.95,
        height * 0.72,
        hw * 1.25,
        height * 0.28,
        hw * 0.55,
        0,
      )
      ..close();
  }

  final Paint _wirePaint = Paint()
    ..color = const Color(0xFF284232)
    ..strokeWidth = 1.4
    ..style = PaintingStyle.stroke;

  final Paint _wireHighlightPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.10)
    ..strokeWidth = 0.6
    ..style = PaintingStyle.stroke;

  final Paint _socketPaint = Paint()
    ..color = const Color(0xFF1F3828)
    ..style = PaintingStyle.fill;

  final Paint _socketCapPaint = Paint()
    ..color = const Color(0xFF8A795D)
    ..style = PaintingStyle.fill;

  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;

  Path? _cachedWirePath;
  double _cachedWidth = -1;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;

    const double swagSpan = 88.0;
    const double topY = 2.0;
    const double sagControlY = 10.5;
    final int swagCount = (size.width / swagSpan).ceil();

    if (_cachedWirePath == null || _cachedWidth != size.width) {
      _cachedWidth = size.width;
      final Path wirePath = Path()..moveTo(0, topY);
      for (int s = 0; s < swagCount; s++) {
        final double x0 = s * swagSpan;
        final double x1 = (s + 1) * swagSpan;
        final double midX = (x0 + x1) / 2;
        wirePath.quadraticBezierTo(midX, sagControlY, x1, topY);
      }
      _cachedWirePath = wirePath;
    }

    canvas.drawPath(_cachedWirePath!, _wirePaint);
    canvas.drawPath(_cachedWirePath!, _wireHighlightPaint);

    final double phase = phaseListenable.value;
    int bulbIndex = 0;

    for (int s = 0; s < swagCount; s++) {
      final double x0 = s * swagSpan;
      for (final double t in const [0.28, 0.72]) {
        final double bx = x0 + swagSpan * t;
        if (bx < 8 || bx > size.width - 8) {
          bulbIndex++;
          continue;
        }

        final double oneMinusT = 1.0 - t;
        final double by =
            oneMinusT * oneMinusT * topY +
            2 * oneMinusT * t * sagControlY +
            t * t * topY;

        final double tiltAngle = bulbIndex.isEven ? -0.16 : 0.16;
        final Color baseColor = _bulbColors[bulbIndex % _bulbColors.length];

        final double twinkle;
        switch (mode) {
          case HolidayLightsMode.solid:
            twinkle = 1.0;
            break;
          case HolidayLightsMode.twinkle:
            twinkle =
                0.50 + 0.50 * (0.5 + 0.5 * math.sin(phase + bulbIndex * 1.45));
            break;
          case HolidayLightsMode.chase:
            final double wave =
                0.5 + 0.5 * math.sin(phase * 2.2 - bulbIndex * 0.70);
            twinkle = math.pow(wave, 2.2).toDouble();
            break;
          case HolidayLightsMode.pulse:
            final double wave = 0.5 + 0.5 * math.sin(phase * 1.5);
            twinkle = 0.20 + 0.80 * (wave * wave);
            break;
          case HolidayLightsMode.off:
            twinkle = 0.0;
            break;
        }

        canvas.save();
        canvas.translate(bx, by);
        canvas.rotate(tiltAngle);

        // 1. Fast layered halo glow (no expensive GPU MaskFilter.blur needed)
        if (twinkle > 0.05) {
          _fillPaint.color = baseColor.withValues(alpha: 0.11 * twinkle);
          canvas.drawOval(
            const Rect.fromLTWH(-6.2, 0.2, 12.4, 14.5),
            _fillPaint,
          );
          _fillPaint.color = baseColor.withValues(alpha: 0.18 * twinkle);
          canvas.drawOval(
            const Rect.fromLTWH(-4.2, 1.5, 8.4, 11.2),
            _fillPaint,
          );
        }

        // 2. Socket base (dark green plastic clip + brass collar)
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-1.8, -0.6, 3.6, 2.4),
            const Radius.circular(0.8),
          ),
          _socketPaint,
        );
        canvas.drawRect(
          const Rect.fromLTWH(-1.5, 1.4, 3.0, 1.0),
          _socketCapPaint,
        );

        // 3. C7 teardrop glass bulb body
        canvas.translate(0, 2.2);
        final double bulbAlpha = mode == HolidayLightsMode.off
            ? 0.22
            : (0.74 + 0.24 * twinkle);
        _fillPaint.color = baseColor.withValues(alpha: bulbAlpha);
        canvas.drawPath(_bulbPath, _fillPaint);

        // 4. Warm inner filament core + specular glass highlight
        if (twinkle > 0.05) {
          _fillPaint.color = Colors.white.withValues(
            alpha: 0.48 + 0.42 * twinkle,
          );
          canvas.drawOval(const Rect.fromLTWH(-1.1, 1.6, 2.2, 4.2), _fillPaint);
        }

        final double specAlpha = mode == HolidayLightsMode.off
            ? 0.20
            : (0.55 * twinkle);
        _fillPaint.color = Colors.white.withValues(alpha: specAlpha);
        canvas.drawOval(const Rect.fromLTWH(-1.4, 1.5, 1.0, 2.6), _fillPaint);

        canvas.restore();
        bulbIndex++;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StringLightsPainter oldDelegate) =>
      oldDelegate.mode != mode;
}
