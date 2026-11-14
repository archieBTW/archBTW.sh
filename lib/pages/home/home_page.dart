import 'dart:async';

import 'package:archbtw_sh/games/super_archbtw.dart';
import 'package:archbtw_sh/global/colors.dart';
import 'package:archbtw_sh/global/site_music_controller.dart';
import 'package:archbtw_sh/pages/overheat/overheat_page.dart';
import 'package:archbtw_sh/widgets/christmas_countdown.dart';
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
  static const List<Color> _cursorColors = [
    kAccentColor,
    kHolidayRed,
    kHolidayGreen,
    kHolidayGold,
  ];

  String _currentText = '';
  int _currentIndex = 0;
  bool _showCursor = true;
  int _cursorColorIndex = 0;
  bool _typingComplete = false;

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
        if (mounted) {
          setState(() {
            _typingComplete = true;
          });
        }
        _cursorTimer = Timer.periodic(const Duration(milliseconds: 500), (
          timer,
        ) {
          if (mounted) {
            setState(() {
              _showCursor = !_showCursor;
              if (_showCursor) {
                _cursorColorIndex =
                    (_cursorColorIndex + 1) % _cursorColors.length;
              }
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
    final double socialSpacing = isDesktop ? 24 : (screenWidth < 360 ? 6 : 14);
    final double bottomPadding = isDesktop ? 16 : 10;
    final Color activeCursorColor = _cursorColors[_cursorColorIndex];

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
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
                          color: _showCursor
                              ? activeCursorColor
                              : Colors.transparent,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'JetBrainsMono',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedOpacity(
                  opacity: _typingComplete ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 600),
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: isDesktop ? 13 : 11,
                        fontFamily: 'JetBrainsMono',
                        letterSpacing: 1.2,
                      ),
                      children: [
                        TextSpan(
                          text: '* ',
                          style: TextStyle(
                            color: kHolidayGold.withValues(alpha: 0.75),
                          ),
                        ),
                        TextSpan(
                          text: 'happy holidays',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.38),
                          ),
                        ),
                        TextSpan(
                          text: ' *',
                          style: TextStyle(
                            color: kHolidayGreen.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
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
                    key: const Key('angel_tree_button'),
                    icon: FontAwesomeIcons.tree,
                    url: 'https://www.salvationarmyusa.org/walmart-angel-tree/',
                    iconSize: iconSize,
                    tooltip: 'adopt an angel / family',
                    hoverColor: kHolidayGreen,
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
                          pageBuilder:
                              (context, animation, secondaryAnimation) {
                                return const OverheatPage();
                              },
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                        ),
                      );
                    },
                  ),
                  SizedBox(width: socialSpacing),
                  SocialIcon(
                    key: const Key('okc_game_button'),
                    icon: FontAwesomeIcons.gamepad,
                    iconSize: iconSize,
                    tooltip: 'play super_archbtw.sh',
                    hoverColor: kAccentColor,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SuperArchBtw(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              SizedBox(height: isDesktop ? 10.0 : 6.0),
              const ChristmasCountdown(),
            ],
          ),
        ),
      ],
    );
  }
}
