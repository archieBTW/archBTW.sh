import 'dart:async';
import 'dart:math' as math;

import 'package:archbtw_sh/global/colors.dart';
import 'package:flutter/material.dart';

class ChristmasCountdown extends StatefulWidget {
  final DateTime Function()? currentTimeProvider;

  const ChristmasCountdown({
    super.key,
    this.currentTimeProvider,
  });

  @override
  State<ChristmasCountdown> createState() => _ChristmasCountdownState();
}

class _ChristmasCountdownState extends State<ChristmasCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  DateTime _getTargetChristmas(DateTime now) {
    if (now.month == 12 && now.day > 25) {
      return DateTime(now.year + 1, 12, 25);
    }
    return DateTime(now.year, 12, 25);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.sizeOf(context).width >= 768.0;
    final now = widget.currentTimeProvider?.call() ?? DateTime.now();

    final bool isChristmasDay = now.month == 12 && now.day == 25;
    final targetChristmas = _getTargetChristmas(now);
    final difference = targetChristmas.difference(now);

    final int days = math.max(0, difference.inDays);
    final int hours = math.max(0, difference.inHours % 24);
    final int minutes = math.max(0, difference.inMinutes % 60);
    final int seconds = math.max(0, difference.inSeconds % 60);

    final double fontSize = isDesktop ? 11.0 : 9.5;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
        child: isChristmasDay
            ? Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: fontSize,
                    letterSpacing: 1.0,
                  ),
                  children: [
                    TextSpan(
                      text: '* ',
                      style: TextStyle(
                        color: kHolidayGold.withValues(alpha: 0.85),
                      ),
                    ),
                    const TextSpan(
                      text: 'merry christmas!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: kHolidayGreen.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              )
            : Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: fontSize,
                    letterSpacing: 1.0,
                  ),
                  children: [
                    TextSpan(
                      text: '// ',
                      style: TextStyle(
                        color: kHolidayGreen.withValues(alpha: 0.85),
                      ),
                    ),
                    TextSpan(
                      text: 'christmas countdown: ',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                    TextSpan(
                      text: '${days}d ',
                      style: const TextStyle(
                        color: kHolidayRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: '${hours.toString().padLeft(2, '0')}h ',
                      style: const TextStyle(
                        color: kHolidayGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: '${minutes.toString().padLeft(2, '0')}m ',
                      style: const TextStyle(
                        color: kHolidayGold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: '${seconds.toString().padLeft(2, '0')}s',
                      style: const TextStyle(
                        color: kHolidayIce,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

