import 'package:archbtw_sh/games/blubber_game.dart';
import 'package:archbtw_sh/pages/music/music_player.dart';
import 'package:archbtw_sh/games/lemon_game.dart';
import 'package:archbtw_sh/games/santa_game.dart';
import 'package:archbtw_sh/global/colors.dart';
import 'package:archbtw_sh/pages/music/album_item.dart';
import 'package:archbtw_sh/pages/overheat/overheat_page.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AlbumDetails extends StatefulWidget {
  final AlbumItem item;
  final bool isDesktop;
  final bool showTitle;
  final bool showPlayer;
  final bool showLyricsButton;
  final bool showLyricsContent;
  final bool? isLyricsExpanded;
  final VoidCallback? onToggleLyrics;

  const AlbumDetails({
    super.key,
    required this.item,
    required this.isDesktop,
    this.showTitle = true,
    this.showPlayer = true,
    this.showLyricsButton = false,
    this.showLyricsContent = true,
    this.isLyricsExpanded,
    this.onToggleLyrics,
  });

  @override
  State<AlbumDetails> createState() => _AlbumDetailsState();
}

class _AlbumDetailsState extends State<AlbumDetails> {
  bool _internalExpanded = false;

  bool get _isExpanded => widget.isLyricsExpanded ?? _internalExpanded;

  void _handleToggle() {
    if (widget.onToggleLyrics != null) {
      widget.onToggleLyrics!();
    } else {
      setState(() {
        _internalExpanded = !_internalExpanded;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double iconSize = widget.isDesktop ? 22 : 18;

    return Column(
      crossAxisAlignment: widget.isDesktop && widget.showTitle
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (widget.showTitle)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            child: Wrap(
              alignment: widget.isDesktop
                  ? WrapAlignment.center
                  : WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 14,
              runSpacing: 10,
              children: [
                Text(
                  widget.item.title,
                  style: TextStyle(
                    color: kTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    fontFamily: 'JetBrainsMono',
                  ),
                ),
                if (widget.item.isLocked) ...[
                  IconButton(
                    tooltip: "launch_protocol: overheat",
                    icon: FaIcon(
                      FontAwesomeIcons.fire,
                      color: const Color(0xFFFF6F00),
                      size: iconSize,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          opaque: false,
                          pageBuilder: (context, anim, secAnim) =>
                              const OverheatPage(),
                          transitionsBuilder: (context, anim, secAnim, child) {
                            return FadeTransition(opacity: anim, child: child);
                          },
                        ),
                      );
                    },
                  ),
                ] else if (widget.item.title.toLowerCase() == 'blubber' ||
                    widget.item.title.toLowerCase() == 'santa\'s cookies' ||
                    widget.item.title.toLowerCase() == 'life\'s lemons') ...[
                  Tooltip(
                    message: _getTooltipForAlbum(widget.item.title),
                    child: ElevatedButton.icon(
                      key: const Key('launch_game_button'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccentColor.withValues(alpha: 0.16),
                        foregroundColor: kAccentColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        side: const BorderSide(
                          color: kAccentColor,
                          width: 1.6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(
                        Icons.sports_esports,
                        color: kAccentColor,
                        size: 18,
                      ),
                      label: Text(
                        _getGameLabelForAlbum(widget.item.title),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'JetBrainsMono',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.8,
                        ),
                      ),
                      onPressed: () {
                        Widget gamePage;
                        final title = widget.item.title.toLowerCase();

                        if (title == 'blubber') {
                          gamePage = const WhaleGame();
                        } else if (title == 'santa\'s cookies') {
                          gamePage = const SantasInvadersGame();
                        } else {
                          gamePage = const LemonsGame();
                        }

                        Navigator.of(context).push(
                          PageRouteBuilder(
                            pageBuilder: (context, anim, secAnim) => gamePage,
                            transitionsBuilder:
                                (context, anim, secAnim, child) {
                                  return FadeTransition(
                                    opacity: anim,
                                    child: child,
                                  );
                                },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (widget.item.isLocked && (widget.showPlayer || !widget.isDesktop))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24),
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "your order is in the oven.",
                    style: TextStyle(
                      color: kTextColor,
                      fontFamily: 'JetBrainsMono',
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "estimated delivery time: march 2027",
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'JetBrainsMono',
                      fontSize: 13,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (widget.showPlayer && widget.item.tracks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: MusicPlayer(
              albumTitle: widget.item.title,
              tracks: widget.item.tracks,
              audioPath: widget.item.audioPath,
              isDesktop: widget.isDesktop,
            ),
          ),
        if (widget.showLyricsButton &&
            !widget.item.isLocked &&
            widget.item.lyrics.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: _handleToggle,
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: kAccentColor,
                  ),
                  label: Text(
                    _isExpanded ? "lyrics.collapse();" : "lyrics.expand();",
                    style: TextStyle(
                      color: kAccentColor,
                      fontFamily: 'JetBrainsMono',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (widget.showLyricsContent &&
            _isExpanded &&
            !widget.item.isLocked &&
            widget.item.lyrics.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: _buildLyricSpans(
                      widget.item.lyrics,
                      isDesktop: widget.isDesktop,
                    ),
                  ),
                  textAlign: TextAlign.start,
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
  return "launch_protocol: gnu/linux";
}

String _getGameLabelForAlbum(String title) {
  final t = title.toLowerCase();
  if (t == 'blubber') return "PLAY: floppy_whale.sh";
  if (t == 'santa\'s cookies') return "PLAY: rudolph_spoke.sh";
  return "PLAY: lifes_lemons.sh";
}

List<TextSpan> _buildLyricSpans(String lyrics, {required bool isDesktop}) {
  final double defaultFontSize = isDesktop ? 16 : 14;
  final double titleFontSize = isDesktop ? 21 : 17;
  final double descriptionFontSize = isDesktop ? 14 : 12;

  final defaultStyle = TextStyle(
    color: kTextColor,
    fontSize: defaultFontSize,
    height: 1.5,
    fontFamily: 'JetBrainsMono',
  );

  final titleStyle = TextStyle(
    color: kAccentColor,
    fontSize: titleFontSize,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.6,
    height: 1.8,
    fontFamily: 'JetBrainsMono',
  );

  final descriptionStyle = TextStyle(
    color: kTextColor,
    fontSize: descriptionFontSize,
    fontStyle: FontStyle.italic,
    height: 1.5,
    fontFamily: 'JetBrainsMono',
  );

  final List<TextSpan> spans = [];
  final lines = lyrics.split('\n');

  bool inDescriptionBlock = false;

  for (final line in lines) {
    final trimmedLine = line.trim();
    if (trimmedLine == '**') {
      inDescriptionBlock = !inDescriptionBlock;
      continue;
    }

    if (inDescriptionBlock) {
      spans.add(TextSpan(text: '$line\n', style: descriptionStyle));
    } else if (trimmedLine.startsWith('[') && trimmedLine.endsWith(']')) {
      final content = trimmedLine.substring(1, trimmedLine.length - 1);
      spans.add(TextSpan(text: '// $content\n', style: titleStyle));
    } else {
      spans.add(TextSpan(text: '$line\n', style: defaultStyle));
    }
  }
  return spans;
}
