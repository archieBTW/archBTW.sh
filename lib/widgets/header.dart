import 'package:archbtw_sh/global/colors.dart';
import 'package:archbtw_sh/widgets/nav_link.dart';
import 'package:flutter/material.dart';

class Header extends StatelessWidget {
  final int currentIndex;
  final Function(int) onItemTapped;

  const Header({
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
              child: Text(
                '// archBTW.',
                style: TextStyle(
                  color: kTextColor,
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontFamily: 'JetBrainsMono',
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
          child: Padding(
            padding: padding,
            child: headerContent,
          ),
        );
      },
    );
  }
}