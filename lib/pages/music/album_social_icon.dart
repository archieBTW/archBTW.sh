import 'package:archbtw_sh/global/colors.dart';
import 'package:archbtw_sh/global/helpers.dart';
import 'package:flutter/material.dart';

class AlbumSocialIcon extends StatelessWidget {
  final IconData icon;
  final String url;
  final double size;

  const AlbumSocialIcon({super.key, 
    required this.icon,
    required this.url,
    this.size = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: Colors.grey, size: size),
      onPressed: () => openUrl(url),
      splashColor: kAccentColor.withOpacity(0.3),
      hoverColor: kAccentColor.withOpacity(0.1),
    );
  }
}