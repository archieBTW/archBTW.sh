import 'dart:math' as math;
import 'package:archbtw_sh/global/colors.dart';
import 'package:flutter/material.dart';

class WaveformLoader extends StatefulWidget {
  final double height;
  final double barWidth;
  final Color? color;

  const WaveformLoader({
    super.key,
    this.height = 50.0,
    this.barWidth = 4.0,
    this.color,
  });

  @override
  State<WaveformLoader> createState() => _WaveformLoaderState();
}

class _WaveformLoaderState extends State<WaveformLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Match CSS duration: 1.2s
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Colors.white;

    return SizedBox(
      height: widget.height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(5, (index) {
          final double delayFactor = index * (1 / 12);

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              double t = (_controller.value - delayFactor) % 1.0;

              double sinVal = math.sin(t * 2 * math.pi);

              double normalized = (sinVal + 1) / 2; 
              double scale = 0.1 + (normalized * 0.9);

              return Container(
                width: widget.barWidth,
                height: widget.height * scale, 
                margin: const EdgeInsets.symmetric(horizontal: 3.0),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}