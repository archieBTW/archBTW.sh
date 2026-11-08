import 'package:flutter/material.dart';

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double gap;
  final double pixelsPerSecond;

  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.gap = 36.0,
    this.pixelsPerSecond = 35.0,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller.forward(from: 0.0);
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final TextPainter tp = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();

        final double textWidth = tp.width;
        final double maxWidth = constraints.maxWidth;

        // If the text fits comfortably, render static text without scrolling
        if (!maxWidth.isFinite || textWidth <= maxWidth) {
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.clip,
          );
        }

        final double loopDistance = textWidth + widget.gap;
        final int durationMs =
            ((loopDistance / widget.pixelsPerSecond) * 1000).round().clamp(
                  2500,
                  30000,
                );
        if (_controller.duration?.inMilliseconds != durationMs) {
          _controller.duration = Duration(milliseconds: durationMs);
          if (!_controller.isAnimating) {
            _controller.repeat();
          }
        }

        return ClipRect(
          child: SizedBox(
            width: maxWidth,
            height: tp.height * 1.15,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final double offset = -(_controller.value * loopDistance);
                return OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: 0,
                  maxWidth: double.infinity,
                  child: Transform.translate(
                    offset: Offset(offset, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.text, style: widget.style, maxLines: 1),
                        SizedBox(width: widget.gap),
                        Text(widget.text, style: widget.style, maxLines: 1),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

