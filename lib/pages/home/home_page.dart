import 'dart:async';

import 'package:archbtw_sh/global/colors.dart';
import 'package:archbtw_sh/global/site_music_controller.dart';
import 'package:archbtw_sh/pages/overheat/overheat_page.dart';
import 'package:archbtw_sh/widgets/social_icons.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin {
  static const String _fullText = "hi. i'm archBTW.";
  String _currentText = '';
  int _currentIndex = 0;
  bool _showCursor = true;

  late final Timer _typingTimer;
  Timer? _cursorTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _typingTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (_currentIndex < _fullText.length) {
        if (mounted) {
          setState(() {
            _currentText = _fullText.substring(0, _currentIndex + 1);
            _currentIndex++;
          });
        }
      } else {
        timer.cancel();
        _cursorTimer = Timer.periodic(const Duration(milliseconds: 500), (
          timer,
        ) {
          if (mounted) {
            setState(() {
              _showCursor = !_showCursor;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _typingTimer.cancel();
    _cursorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 768.0;

    final double titleFontSize = isDesktop ? 36 : 24;
    final double iconSize = isDesktop ? 24 : 18;
    final double socialSpacing = isDesktop ? 24 : 16;
    final double bottomPadding = isDesktop ? 64 : 32;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: _currentText,
                    style: TextStyle(
                      color: kTextColor,
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
                  TextSpan(
                    text: _showCursor ? '|' : ' ',
                    style: TextStyle(
                      color: _showCursor ? kAccentColor : Colors.transparent,
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ListenableBuilder(
          listenable: SiteMusicController.instance,
          builder: (context, child) {
            final bool toastVisible =
                SiteMusicController.instance.shouldShowFloatingToast;
            return AnimatedPadding(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(
                bottom: bottomPadding + (toastVisible ? 68.0 : 0.0),
              ),
              child: child,
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SocialIcon(
                icon: FontAwesomeIcons.linux,
                url: 'https://welledumacated.dev',
                iconSize: iconSize,
              ),
              SizedBox(width: socialSpacing),
              SocialIcon(
                icon: FontAwesomeIcons.computer,
                url: 'https://archerwoods.dev',
                iconSize: iconSize,
              ),
              SizedBox(width: socialSpacing),
              SocialIcon(
                icon: FontAwesomeIcons.github,
                url: 'https://www.github.com/archieBTW',
                iconSize: iconSize,
              ),
              SizedBox(width: socialSpacing),
              SocialIcon(
                icon: FontAwesomeIcons.code,
                iconSize: iconSize,
                onPressed: () {
                  Navigator.pushNamed(context, '/source');
                },
              ),
              SizedBox(width: socialSpacing),
              SocialIcon(
                icon: FontAwesomeIcons.fire,
                iconSize: iconSize,
                tooltip: 'overheat',
                hoverColor: const Color(0xFFFF6F00),
                onPressed: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      opaque: false,
                      pageBuilder: (context, animation, secondaryAnimation) {
                        return const OverheatPage();
                      },
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
