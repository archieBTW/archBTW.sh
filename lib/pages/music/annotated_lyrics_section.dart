import 'dart:math' as math;

import 'package:archbtw_sh/global/colors.dart';
import 'package:archbtw_sh/global/site_music_controller.dart';
import 'package:archbtw_sh/pages/music/album_item.dart';
import 'package:archbtw_sh/pages/music/lyric_annotations.dart';
import 'package:flutter/material.dart';

/// Interactive Rap Genius-style lyrics viewer with per-track and per-line
/// breakdowns tailored to the archBTW.sh terminal aesthetic.
class AnnotatedLyricsSection extends StatefulWidget {
  final AlbumItem item;
  final bool isDesktop;

  const AnnotatedLyricsSection({
    super.key,
    required this.item,
    required this.isDesktop,
  });

  @override
  State<AnnotatedLyricsSection> createState() => _AnnotatedLyricsSectionState();
}

class _AnnotatedLyricsSectionState extends State<AnnotatedLyricsSection> {
  final SiteMusicController _musicController = SiteMusicController.instance;
  final GlobalKey _lyricsColumnKey = GlobalKey();
  final Map<int, GlobalKey> _itemKeys = {};

  late ParsedAlbumLyrics _parsed;
  int? _selectedItemIndex;
  int? _hoveredItemIndex;
  double _desktopCardTopOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _parsed = parseAlbumLyrics(widget.item.lyrics);
    _musicController.addListener(_onMusicChanged);
  }

  @override
  void didUpdateWidget(covariant AnnotatedLyricsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.lyrics != widget.item.lyrics ||
        oldWidget.item.title != widget.item.title) {
      _parsed = parseAlbumLyrics(widget.item.lyrics);
      _itemKeys.clear();
      _selectedItemIndex = null;
      _hoveredItemIndex = null;
      _desktopCardTopOffset = 0.0;
    } else if (oldWidget.isDesktop != widget.isDesktop &&
        widget.isDesktop &&
        _selectedItemIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncDesktopCardOffset();
      });
    }
  }

  @override
  void dispose() {
    _musicController.removeListener(_onMusicChanged);
    super.dispose();
  }

  void _onMusicChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  GlobalKey _keyForItem(int index) {
    return _itemKeys.putIfAbsent(index, () => GlobalKey());
  }

  int? get _playingTrackIndex {
    if (!_musicController.isAlbumLoaded(widget.item.audioPath)) {
      return null;
    }
    final idx = _musicController.currentTrackIndex;
    if (idx < 0 || idx >= _parsed.tracks.length) return null;
    return idx;
  }

  void _selectItem(
    int index, {
    bool toggleIfSelected = false,
    bool scrollIntoView = false,
  }) {
    if (index < 0 || index >= _parsed.allItems.length) return;

    if (toggleIfSelected && _selectedItemIndex == index) {
      setState(() {
        _selectedItemIndex = null;
      });
      return;
    }

    final int? previousIndex = _selectedItemIndex;
    final bool shouldScroll =
        scrollIntoView || (!widget.isDesktop && previousIndex != null);

    setState(() {
      _selectedItemIndex = index;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncDesktopCardOffset();
      if (shouldScroll) {
        final ctx = _itemKeys[index]?.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: 0.18,
          );
        }
      }
    });
  }

  void _syncDesktopCardOffset() {
    if (!mounted || !widget.isDesktop || _selectedItemIndex == null) return;

    final columnBox =
        _lyricsColumnKey.currentContext?.findRenderObject() as RenderBox?;
    final itemBox = _itemKeys[_selectedItemIndex!]?.currentContext
        ?.findRenderObject() as RenderBox?;

    if (columnBox == null ||
        itemBox == null ||
        !columnBox.hasSize ||
        !itemBox.hasSize) {
      return;
    }

    final double itemTop = itemBox.localToGlobal(Offset.zero).dy;
    final double columnTop = columnBox.localToGlobal(Offset.zero).dy;
    final double rawOffset = itemTop - columnTop;
    final double maxOffset = math.max(0.0, columnBox.size.height - 260.0);
    final double clampedOffset = rawOffset.clamp(0.0, maxOffset);

    if ((clampedOffset - _desktopCardTopOffset).abs() > 1.0) {
      setState(() {
        _desktopCardTopOffset = clampedOffset;
      });
    }
  }

  void _closeAnnotation() {
    setState(() {
      _selectedItemIndex = null;
    });
  }

  void _stepSelection(int delta) {
    if (_selectedItemIndex == null) return;
    final next = _selectedItemIndex! + delta;
    if (next < 0 || next >= _parsed.allItems.length) return;
    _selectItem(next, scrollIntoView: true);
  }

  @override
  Widget build(BuildContext context) {
    if (_parsed.tracks.isEmpty) {
      return const SizedBox.shrink();
    }

    if (widget.isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: KeyedSubtree(
              key: _lyricsColumnKey,
              child: _buildLyricsList(),
            ),
          ),
          const SizedBox(width: 28),
          Expanded(
            flex: 2,
            child: _buildDesktopAnnotationRail(),
          ),
        ],
      );
    }

    return _buildLyricsList();
  }

  Widget _buildLyricsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int t = 0; t < _parsed.tracks.length; t++) ...[
          if (t > 0) const SizedBox(height: 28),
          _buildTrackSection(_parsed.tracks[t]),
        ],
      ],
    );
  }

  Widget _buildTrackSection(ParsedLyricTrack track) {
    final header = track.headerItem;
    final bool isHeaderSelected = _selectedItemIndex == header.index;
    final bool isHeaderHovered = _hoveredItemIndex == header.index;
    final bool isPlayingTrack = _playingTrackIndex == track.trackIndex;

    final double titleFontSize = widget.isDesktop ? 20 : 16.5;
    final TextStyle titleStyle = TextStyle(
      color: kAccentColor,
      fontSize: titleFontSize,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.6,
      height: 1.5,
      fontFamily: 'JetBrainsMono',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hoveredItemIndex = header.index),
          onExit: (_) {
            if (_hoveredItemIndex == header.index) {
              setState(() => _hoveredItemIndex = null);
            }
          },
          child: GestureDetector(
            key: Key('lyric_track_${track.trackIndex}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _selectItem(header.index, toggleIfSelected: true),
            child: AnimatedContainer(
              key: _keyForItem(header.index),
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isHeaderSelected
                    ? kAccentColor.withValues(alpha: 0.2)
                    : isHeaderHovered
                        ? kAccentColor.withValues(alpha: 0.1)
                        : kAccentColor.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(6),
                border: Border(
                  left: BorderSide(
                    color: isHeaderSelected || isHeaderHovered
                        ? kAccentColor
                        : kAccentColor.withValues(alpha: 0.55),
                    width: isHeaderSelected ? 3.5 : 2.5,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '// ${track.title}',
                            style: titleStyle,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isPlayingTrack)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: kAccentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '♪',
                        style: TextStyle(
                          color: kAccentColor,
                          fontFamily: 'JetBrainsMono',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isHeaderSelected
                          ? kAccentColor.withValues(alpha: 0.28)
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isHeaderSelected
                            ? kAccentColor
                            : Colors.white12,
                      ),
                    ),
                    child: Text(
                      isHeaderSelected ? '[ inspecting ]' : '[ track info ]',
                      style: TextStyle(
                        color: isHeaderSelected ? Colors.white : Colors.white60,
                        fontFamily: 'JetBrainsMono',
                        fontSize: 10.5,
                        fontWeight: isHeaderSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!widget.isDesktop && isHeaderSelected)
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: _buildAnnotationCard(header),
          ),
        const SizedBox(height: 10),
        for (final row in track.rows)
          if (row.isStanzaBreak)
            const SizedBox(height: 12)
          else
            _buildLyricLineRow(row.item!),
      ],
    );
  }

  Widget _buildLyricLineRow(AnnotatableItem item) {
    final bool isSelected = _selectedItemIndex == item.index;
    final bool isHovered = _hoveredItemIndex == item.index;
    final double fontSize = widget.isDesktop ? 15.0 : 13.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hoveredItemIndex = item.index),
            onExit: (_) {
              if (_hoveredItemIndex == item.index) {
                setState(() => _hoveredItemIndex = null);
              }
            },
            child: GestureDetector(
              key: Key('lyric_line_${item.index}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _selectItem(item.index, toggleIfSelected: true),
              child: AnimatedContainer(
                key: _keyForItem(item.index),
                duration: const Duration(milliseconds: 130),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? kAccentColor.withValues(alpha: 0.25)
                      : isHovered
                          ? kAccentColor.withValues(alpha: 0.13)
                          : Colors.white.withValues(alpha: 0.045),
                  borderRadius: BorderRadius.circular(4),
                  border: Border(
                    left: BorderSide(
                      color: isSelected
                          ? kAccentColor
                          : isHovered
                              ? kAccentColor.withValues(alpha: 0.8)
                              : kAccentColor.withValues(alpha: 0.24),
                      width: isSelected ? 3.0 : 2.0,
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.text,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.92),
                          fontSize: fontSize,
                          height: 1.5,
                          fontFamily: 'JetBrainsMono',
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (isSelected || isHovered) ...[
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          isSelected ? '◄' : '?',
                          style: TextStyle(
                            color: isSelected
                                ? kAccentColor
                                : kAccentColor.withValues(alpha: 0.75),
                            fontFamily: 'JetBrainsMono',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!widget.isDesktop && isSelected)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 10),
            child: _buildAnnotationCard(item),
          ),
      ],
    );
  }

  Widget _buildDesktopAnnotationRail() {
    if (_selectedItemIndex == null) {
      return _buildDesktopGuideCard();
    }

    final item = _parsed.allItems[_selectedItemIndex!];
    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(top: _desktopCardTopOffset),
      child: _buildAnnotationCard(item),
    );
  }

  Widget _buildDesktopGuideCard() {
    final firstTrack = _parsed.tracks.first;

    return Container(
      key: const Key('annotation_guide_card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0B14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kAccentColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.terminal, size: 16, color: kAccentColor),
              SizedBox(width: 8),
              Text(
                '// ANNOTATIONS.MD',
                style: TextStyle(
                  color: kAccentColor,
                  fontFamily: 'JetBrainsMono',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Rap Genius-style breakdowns are loaded for every track and bar on this album.',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'JetBrainsMono',
              fontSize: 13,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '• click any // track title for song themes & context\n'
            '• click any highlighted lyric line to unpack wordplay, allusions & meaning\n'
            '• use prev / next inside the card to step line-by-line',
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'JetBrainsMono',
              fontSize: 12,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 16),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: InkWell(
              key: const Key('inspect_first_track_button'),
              onTap: () => _selectItem(firstTrack.headerItem.index),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: kAccentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: kAccentColor),
                ),
                child: Text(
                  '[ inspect "${firstTrack.title}" → ]',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnotationCard(AnnotatableItem item) {
    final bool isTrack = item.kind == AnnotatableTargetKind.track;
    final TrackBreakdown? trackBreakdown =
        getTrackBreakdown(widget.item.title, item.trackTitle);
    final LyricAnnotation? lineAnnotation = isTrack
        ? null
        : getLineAnnotation(widget.item.title, item.trackTitle, item.text);

    final String breakdownText = isTrack
        ? (trackBreakdown?.overview ??
            'Track overview for "${item.trackTitle}".')
        : (lineAnnotation?.summary ??
            'Lyric note for "${item.text}" on "${item.trackTitle}".');

    final List<String> tags = isTrack
        ? (trackBreakdown?.tags ?? const [])
        : (lineAnnotation?.tags ?? const []);

    final bool hasPrev = item.index > 0;
    final bool hasNext = item.index < _parsed.allItems.length - 1;
    final ParsedLyricTrack parentTrack = _parsed.tracks[item.trackIndex];

    return Container(
      key: const Key('annotation_card'),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0B14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: kAccentColor.withValues(alpha: 0.55),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: kAccentColor.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: kAccentColor, width: 3.5),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card top header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: kAccentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isTrack ? 'TRACK BREAKDOWN' : 'LYRIC ANNOTATION',
                      style: const TextStyle(
                        color: kAccentColor,
                        fontFamily: 'JetBrainsMono',
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isTrack
                          ? 'TRACK ${item.trackIndex + 1} / ${_parsed.tracks.length}'
                          : 'LINE ${item.lineNumber} / ${item.totalLinesInTrack}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontFamily: 'JetBrainsMono',
                        fontSize: 10.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: InkWell(
                      key: const Key('annotation_close_button'),
                      onTap: _closeAnnotation,
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          '[ x ]',
                          style: TextStyle(
                            color: Colors.white60,
                            fontFamily: 'JetBrainsMono',
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (!isTrack) ...[
                const SizedBox(height: 10),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: InkWell(
                    key: const Key('annotation_track_breadcrumb'),
                    onTap: () => _selectItem(
                      parentTrack.headerItem.index,
                      scrollIntoView: true,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '// ${item.trackTitle}',
                              style: const TextStyle(
                                color: kAccentColor,
                                fontFamily: 'JetBrainsMono',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '(track info)',
                            style: TextStyle(
                              color: Colors.white38,
                              fontFamily: 'JetBrainsMono',
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              // Quoted target
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(5),
                  border: Border(
                    left: BorderSide(
                      color: kAccentColor.withValues(alpha: 0.7),
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  isTrack ? '// ${item.text}' : '"${item.text}"',
                  style: TextStyle(
                    color: isTrack ? kAccentColor : Colors.white,
                    fontFamily: 'JetBrainsMono',
                    fontSize: isTrack ? 15 : 13,
                    fontWeight: isTrack ? FontWeight.bold : FontWeight.w500,
                    fontStyle: isTrack ? FontStyle.normal : FontStyle.italic,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Breakdown text
              Text(
                breakdownText,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                  height: 1.65,
                ),
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: kAccentColor.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: kAccentColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '#$tag',
                        style: const TextStyle(
                          color: kAccentColor,
                          fontFamily: 'JetBrainsMono',
                          fontSize: 10.5,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 10),
              // Prev / Next footer navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNavAction(
                    key: const Key('annotation_prev_button'),
                    label: '[ ← prev ]',
                    enabled: hasPrev,
                    onTap: () => _stepSelection(-1),
                  ),
                  Text(
                    '${item.index + 1} / ${_parsed.allItems.length}',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                    ),
                  ),
                  _buildNavAction(
                    key: const Key('annotation_next_button'),
                    label: '[ next → ]',
                    enabled: hasNext,
                    onTap: () => _stepSelection(1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavAction({
    required Key key,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: InkWell(
        key: key,
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              color: enabled ? kAccentColor : Colors.white24,
              fontFamily: 'JetBrainsMono',
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
