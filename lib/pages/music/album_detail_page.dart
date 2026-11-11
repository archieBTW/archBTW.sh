import 'package:archbtw_sh/global/colors.dart';
import 'package:archbtw_sh/pages/music/album_art.dart';
import 'package:archbtw_sh/pages/music/album_details.dart';
import 'package:archbtw_sh/pages/music/album_item.dart';
import 'package:archbtw_sh/widgets/holiday_snow_overlay.dart';
import 'package:flutter/material.dart';

class AlbumDetailPage extends StatefulWidget {
  final AlbumItem item;
  const AlbumDetailPage({super.key, required this.item});

  @override
  State<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends State<AlbumDetailPage> {
  bool _isLyricsExpanded = false;

  void _toggleLyrics() {
    setState(() {
      _isLyricsExpanded = !_isLyricsExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: kTextColor),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final bool isDesktop = constraints.maxWidth > 800.0;

                        final albumArt = AlbumArt(item: widget.item);

                        if (isDesktop) {
                          return Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        children: [
                                          albumArt,
                                          AlbumDetails(
                                            item: widget.item,
                                            isDesktop: isDesktop,
                                            showTitle: true,
                                            showPlayer: false,
                                            showLyricsButton: false,
                                            showLyricsContent: false,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 32.0),
                                    Expanded(
                                      flex: 3,
                                      child: AlbumDetails(
                                        item: widget.item,
                                        isDesktop: isDesktop,
                                        showTitle: false,
                                        showPlayer: true,
                                        showLyricsButton: true,
                                        showLyricsContent: true,
                                        isLyricsExpanded: _isLyricsExpanded,
                                        onToggleLyrics: _toggleLyrics,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        } else {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              albumArt,
                              AlbumDetails(
                                item: widget.item,
                                isDesktop: isDesktop,
                                showTitle: true,
                                showPlayer: true,
                                showLyricsButton: true,
                                showLyricsContent: true,
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Positioned.fill(child: HolidaySnowOverlay()),
        ],
      ),
    );
  }
}
