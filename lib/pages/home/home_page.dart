

import 'dart:async';

import 'package:archbtw_sh/global/colors.dart';
import 'package:archbtw_sh/widgets/social_icons.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage();

  @override
  State<HomePage> createState() =>  _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String _fullText = "hi. i'm archBTW.";
  String _currentText = '';
  int _currentIndex = 0;
  bool _showCursor = true;
  
  late final Timer _typingTimer;
  late final Timer _cursorTimer;

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
      }
    });
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          _showCursor = !_showCursor;
        });
      }
    });
  }

  @override
  void dispose() {
    _typingTimer.cancel();
    _cursorTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SocialIcon(
                icon: FontAwesomeIcons.spotify,
                url: 'https://open.spotify.com/artist/54LLXYgKGZTqH9tZzsmDtS',
                iconSize: iconSize,
              ),
              SizedBox(width: socialSpacing),
              SocialIcon(
                icon: FontAwesomeIcons.tiktok,
                url: 'https://www.tiktok.com/@archbtw.music',
                iconSize: iconSize,
              ),
              SizedBox(width: socialSpacing),
              SocialIcon(
                icon: FontAwesomeIcons.soundcloud,
                url: 'https://soundcloud.com/archbtw',
                iconSize: iconSize,
              ),
              SizedBox(width: socialSpacing),
              SocialIcon(
                icon: FontAwesomeIcons.youtube,
                url: 'https://www.youtube.com/channel/UCEkivs08T2wb9m6NSuryc8A',
                iconSize: iconSize,
              ),
              SizedBox(width: socialSpacing),
              SocialIcon(
                icon: FontAwesomeIcons.github,
                url: 'https://www.github.com/archieBTW',
                iconSize: iconSize,
              ),
            ],
          ),
        ),
      ],
    );
  }

}

