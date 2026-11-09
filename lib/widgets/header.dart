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
            ? const EdgeInsets.symmetric(horizontal: 48.0, vertical: 16.0)
            : const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0);

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
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: kHolidayGold,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
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
          ],
        );
        return Container(
          color: kBackgroundColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: padding,
                child: headerContent,
              ),
              const _HolidayStringLights(),
            ],
          ),
        );
      },
    );
  }
}

class _HolidayStringLights extends StatefulWidget {
  const _HolidayStringLights();

  @override
  State<_HolidayStringLights> createState() => _HolidayStringLightsState();
}

class _HolidayStringLightsState extends State<_HolidayStringLights>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: 22,
        width: double.infinity,
        child: CustomPaint(
          painter: _StringLightsPainter(animation: _controller),
        ),
      ),
    );
  }
}

class _StringLightsPainter extends CustomPainter {
  final Animation<double> animation;

  _StringLightsPainter({required this.animation}) : super(repaint: animation);

  static const List<Color> _bulbColors = [
    kHolidayRed,
    kHolidayGreen,
    kHolidayGold,
    kAccentColor,
    kHolidayIce,
  ];

  ///Builds a classic C7 teardrop Christmas bulb contour centered at (0, 0)
  ///where y=0 is the bottom of the socket and y=height is the pointed tip.
  Path _buildBulbPath(double width, double height) {
    final double hw = width / 2;
    return Path()
      ..moveTo(-hw * 0.55, 0)
      ..cubicTo(
        -hw * 1.25,
        height * 0.28,
        -hw * 0.95,
        height * 0.72,
        0,
        height,
      )
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

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;

    const double swagSpan = 88.0;
    const double topY = 2.0;
    const double sagControlY = 10.5;
    final int swagCount = (size.width / swagSpan).ceil();

    // Draw dark pine-tinted electrical cord
    final wirePaint = Paint()
      ..color = const Color(0xFF284232)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final wireHighlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    final Path wirePath = Path()..moveTo(0, topY);
    for (int s = 0; s < swagCount; s++) {
      final double x0 = s * swagSpan;
      final double x1 = (s + 1) * swagSpan;
      final double midX = (x0 + x1) / 2;
      wirePath.quadraticBezierTo(midX, sagControlY, x1, topY);
    }
    canvas.drawPath(wirePath, wirePaint);
    canvas.drawPath(wirePath, wireHighlightPaint);

    // Place 2 Christmas bulbs per swag (at t = 0.28 and t = 0.72)
    final double phase = animation.value * math.pi * 2;
    int bulbIndex = 0;

    final socketPaint = Paint()
      ..color = const Color(0xFF1F3828)
      ..style = PaintingStyle.fill;
    final socketCapPaint = Paint()
      ..color = const Color(0xFF8A795D)
      ..style = PaintingStyle.fill;

    for (int s = 0; s < swagCount; s++) {
      final double x0 = s * swagSpan;
      for (final double t in const [0.28, 0.72]) {
        final double bx = x0 + swagSpan * t;
        if (bx < 8 || bx > size.width - 8) {
          bulbIndex++;
          continue;
        }

        // Exact y on the quadratic Bezier curve: (1-t)^2*y0 + 2(1-t)t*yc + t^2*y1
        final double oneMinusT = 1.0 - t;
        final double by = oneMinusT * oneMinusT * topY +
            2 * oneMinusT * t * sagControlY +
            t * t * topY;

        // Slight alternating tilt so bulbs hang naturally off the curved cord
        final double tiltAngle = (bulbIndex.isEven ? -0.16 : 0.16);
        final Color baseColor = _bulbColors[bulbIndex % _bulbColors.length];
        final double twinkle =
            0.50 + 0.50 * (0.5 + 0.5 * math.sin(phase + bulbIndex * 1.45));

        canvas.save();
        canvas.translate(bx, by);
        canvas.rotate(tiltAngle);

        // 1. Soft outer ambient halo glow
        final Paint glowPaint = Paint()
          ..color = baseColor.withValues(alpha: 0.30 * twinkle)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.5);
        canvas.drawOval(
          Rect.fromCenter(
            center: const Offset(0, 6.8),
            width: 8.5,
            height: 11.0,
          ),
          glowPaint,
        );

        // 2. Socket base (dark green plastic clip + brass collar)
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-1.8, -0.6, 3.6, 2.4),
            const Radius.circular(0.8),
          ),
          socketPaint,
        );
        canvas.drawRect(
          const Rect.fromLTWH(-1.5, 1.4, 3.0, 1.0),
          socketCapPaint,
        );

        // 3. C7 teardrop glass bulb body
        canvas.save();
        canvas.translate(0, 2.2);
        final Path bulbPath = _buildBulbPath(5.6, 9.2);

        final Paint glassPaint = Paint()
          ..color = baseColor.withValues(alpha: 0.72 + 0.26 * twinkle)
          ..style = PaintingStyle.fill;
        canvas.drawPath(bulbPath, glassPaint);

        // 4. Warm inner filament core + specular glass highlight
        final Paint corePaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.45 + 0.45 * twinkle)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
        canvas.drawOval(
          Rect.fromCenter(
            center: const Offset(0, 3.6),
            width: 2.2,
            height: 4.2,
          ),
          corePaint,
        );

        final Paint specularPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.55 * twinkle)
          ..style = PaintingStyle.fill;
        canvas.drawOval(
          const Rect.fromLTWH(-1.4, 1.5, 1.0, 2.6),
          specularPaint,
        );

        canvas.restore();
        canvas.restore();
        bulbIndex++;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StringLightsPainter oldDelegate) => false;
}
