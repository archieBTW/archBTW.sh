import 'package:archbtw_sh/global/colors.dart';
import 'package:archbtw_sh/global/helpers.dart';
import 'package:flutter/material.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SocialIcon extends StatelessWidget {
  final dynamic icon;
  final String? url;
  final double iconSize;
  final VoidCallback? onPressed;

  const SocialIcon({super.key, 
    required this.icon,
    this.url,
    this.iconSize = 18.0,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: icon is FaIconData
          ? FaIcon(icon as FaIconData, color: Colors.grey, size: iconSize)
          : Icon(icon as IconData, color: Colors.grey, size: iconSize),
      onPressed: onPressed ?? () {
        if (url != null) openUrl(url!);
      },
      splashColor: kAccentColor.withOpacity(0.3),
      hoverColor: kAccentColor.withOpacity(0.1),
    );
  }
}