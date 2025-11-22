import 'package:archbtw_sh/global/colors.dart';
import 'package:archbtw_sh/global/helpers.dart';
import 'package:flutter/material.dart';

class SocialIcon extends StatelessWidget {
  final IconData icon;
  final String url;
  final double iconSize;

  const SocialIcon({super.key, 
    required this.icon,
    required this.url,
    this.iconSize = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: Colors.grey, size: iconSize),
      onPressed: () => openUrl(url),
      splashColor: kAccentColor.withOpacity(0.3),
      hoverColor: kAccentColor.withOpacity(0.1),
    );
  }
}