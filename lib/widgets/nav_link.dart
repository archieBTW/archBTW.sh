import 'package:archbtw_sh/global/colors.dart';
import 'package:flutter/material.dart';

class NavLink extends StatelessWidget {
  final String title;
  final int index;
  final int currentIndex;
  final VoidCallback onTap;
  final double fontSize;

  const NavLink({super.key, 
    required this.title,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    this.fontSize = 14.0,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = index == currentIndex;

    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        splashFactory: NoSplash.splashFactory,
        overlayColor: Colors.transparent,
        foregroundColor: isActive ? kTextColor : Colors.grey,
        
        textStyle: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: fontSize,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      child: Text(title),
    );
  }
}