import 'package:archbtw_sh/global/colors.dart';
import 'package:archbtw_sh/global/helpers.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SocialIcon extends StatelessWidget {
  final dynamic icon;
  final String? url;
  final double iconSize;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final Color? hoverColor;

  const SocialIcon({
    super.key,
    required this.icon,
    this.url,
    this.iconSize = 18.0,
    this.onPressed,
    this.tooltip,
    this.color,
    this.hoverColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveHover = hoverColor ?? kAccentColor;
    final Widget iconWidget = icon is FaIconData
        ? FaIcon(
            icon as FaIconData,
            color: color ?? Colors.grey,
            size: iconSize,
          )
        : Icon(
            icon as IconData,
            color: color ?? Colors.grey,
            size: iconSize,
          );

    return IconButton(
      tooltip: tooltip,
      icon: iconWidget,
      onPressed: onPressed ??
          () {
            if (url != null) openUrl(url!);
          },
      splashColor: effectiveHover.withValues(alpha: 0.3),
      hoverColor: effectiveHover.withValues(alpha: 0.1),
    );
  }
}
