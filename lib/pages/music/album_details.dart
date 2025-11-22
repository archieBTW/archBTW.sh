import 'package:archbtw_sh/games/blubber_game.dart';
import 'package:archbtw_sh/games/interject_game.dart';
import 'package:archbtw_sh/games/lemon_game.dart';
import 'package:archbtw_sh/games/santa_game.dart';
import 'package:archbtw_sh/global/colors.dart';
import 'package:archbtw_sh/pages/music/album_item.dart';
import 'package:archbtw_sh/pages/music/album_social_icon.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AlbumDetails extends StatelessWidget {
  final AlbumItem item;
  final bool isDesktop;
  const AlbumDetails({super.key, required this.item, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final double iconSize = isDesktop ? 22 : 18;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            0,
          ), // Match art padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: TextStyle(
                  color: kTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  fontFamily: 'JetBrainsMono',
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              if (!item.soundCloudOnly)
                AlbumSocialIcon(
                  icon: FontAwesomeIcons.spotify,
                  url: item.spotifyUrl,
                  size: iconSize,
                ),
              const SizedBox(width: 8),
              if (!item.soundCloudOnly)
                AlbumSocialIcon(
                  icon: FontAwesomeIcons.apple,
                  url: item.appleMusicUrl,
                  size: iconSize,
                ),
              const SizedBox(width: 8),
              AlbumSocialIcon(
                icon: FontAwesomeIcons.soundcloud,
                url: item.soundCloudUrl,
                size: iconSize,
              ),
              const SizedBox(width: 8),
              if (!item.soundCloudOnly)
                AlbumSocialIcon(
                  icon: FontAwesomeIcons.youtube,
                  url: item.youtubeUrl,
                  size: iconSize,
                ),
              if (item.title.toLowerCase() == 'blubber' ||
                  item.title.toLowerCase() == 'santa\'s cookies' ||
                  item.title.toLowerCase() == 'life\'s lemons' ||
                  item.title.toLowerCase().contains('interject')) ...[
                // New Check
                const SizedBox(width: 16),
                Container(
                  width: 1,
                  height: 20,
                  color: Colors.grey.withOpacity(0.5),
                ),
                const SizedBox(width: 16),
                IconButton(
                  // Dynamic Tooltip
                  tooltip: _getTooltipForAlbum(item.title),
                  icon: Icon(
                    FontAwesomeIcons.terminal,
                    color: kAccentColor,
                    size: iconSize,
                  ),
                  onPressed: () {
                    Widget gamePage;
                    final title = item.title.toLowerCase();

                    if (title == 'blubber') {
                      gamePage = WhaleGame();
                    } else if (title == 'santa\'s cookies') {
                      gamePage = const SantasInvadersGame();
                    } else if (title == 'life\'s lemons') {
                      gamePage = const LemonsGame();
                    } else {
                      // Default to the new game for the interject album
                      gamePage = const InterjectGame();
                    }

                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, anim, secAnim) => gamePage,
                        transitionsBuilder: (context, anim, secAnim, child) {
                          return FadeTransition(opacity: anim, child: child);
                        },
                      ),
                    );
                  },
                ),
              ],

              // if (item.title.toLowerCase() == 'blubber' || item.title.toLowerCase() == 'santa\'s cookies' || item.title.toLowerCase() == 'life\'s lemons') ...[
              //   const SizedBox(width: 16),
              //   Container(
              //     width: 1,
              //     height: 20,
              //     color: Colors.grey.withOpacity(0.5),
              //   ),
              //   const SizedBox(width: 16),
              //   IconButton(
              //     tooltip: item.title.toLowerCase() == 'blubber'
              //         ? "launch_protocol: gravity"
              //         : "launch_protocol: chimney",
              //     icon: Icon(
              //       FontAwesomeIcons.terminal,
              //       color: kAccentColor,
              //       size: iconSize
              //     ),
              //     onPressed: () {
              //       Widget gamePage;
              //       if (item.title.toLowerCase() == 'blubber') {
              //         gamePage = WhaleGame(); // Your existing game
              //       } else if (item.title.toLowerCase() == 'santa\'s cookies') {
              //         gamePage = const SantasInvadersGame(); // The new game
              //       } else {
              //         gamePage = const LemonsGame();
              //       }

              //       Navigator.of(context).push(
              //         PageRouteBuilder(
              //           pageBuilder: (context, anim, secAnim) => gamePage,
              //           transitionsBuilder: (context, anim, secAnim, child) {
              //             return FadeTransition(opacity: anim, child: child);
              //           },
              //         ),
              //       );
              //     },
              //   ),
              // ]
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: _buildLyricSpans(item.lyrics, isDesktop: isDesktop),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _getTooltipForAlbum(String title) {
  final t = title.toLowerCase();
  if (t == 'blubber') return "launch_protocol: gravity";
  if (t == 'santa\'s cookies') return "launch_protocol: chimney";
  if (t.contains('interject')) return "launch_protocol: gnu/linux";
  return "launch_protocol: citrus"; // lemons
}

List<TextSpan> _buildLyricSpans(String lyrics, {required bool isDesktop}) {
  final double defaultFontSize = isDesktop ? 16 : 14;
  final double specialFontSize = isDesktop ? 22 : 18;

  final defaultStyle = TextStyle(
    color: kTextColor,
    fontSize: defaultFontSize,
    height: 1.5,
    fontFamily: 'JetBrainsMono',
  );
  final specialStyle = TextStyle(
    color: kAccentColor,
    fontSize: specialFontSize,
    fontWeight: FontWeight.bold,
    height: 1.5,
    fontFamily: 'JetBrainsMono',
  );

  final List<TextSpan> spans = [];
  final lines = lyrics.split('\n');

  for (final line in lines) {
    final trimmedLine = line.trim();

    if (trimmedLine.startsWith('[') && trimmedLine.endsWith(']')) {
      final content = trimmedLine.substring(1, trimmedLine.length - 1);
      spans.add(TextSpan(text: '// $content\n', style: specialStyle));
    } else {
      spans.add(TextSpan(text: '$line\n', style: defaultStyle));
    }
  }
  return spans;
}
