import 'dart:async';
import 'package:archbtw_sh/global/colors.dart';
import 'package:archbtw_sh/global/site_music_controller.dart';
import 'package:archbtw_sh/widgets/marquee_text.dart';
import 'package:flutter/material.dart';

class MusicPlayer extends StatefulWidget {
  final String albumTitle;
  final List<String> tracks;
  final String audioPath;
  final bool isDesktop;

  const MusicPlayer({
    super.key,
    this.albumTitle = '',
    required this.tracks,
    required this.audioPath,
    this.isDesktop = true,
  });

  @override
  State<MusicPlayer> createState() => _MusicPlayerState();
}

class _MusicPlayerState extends State<MusicPlayer> {
  final SiteMusicController _controller = SiteMusicController.instance;
  int _localTrackIndex = 0;
  double? _dragValueMs;

  bool get _isThisAlbumActive => _controller.isAlbumLoaded(widget.audioPath);

  int get _currentTrackIndex => _isThisAlbumActive
      ? _controller.currentTrackIndex.clamp(0, widget.tracks.length - 1)
      : _localTrackIndex.clamp(0, widget.tracks.length - 1);

  bool get _isPlaying => _isThisAlbumActive && _controller.isPlaying;

  Duration get _position =>
      _isThisAlbumActive ? _controller.position : Duration.zero;

  Duration get _duration =>
      _isThisAlbumActive ? _controller.duration : Duration.zero;

  @override
  void initState() {
    super.initState();
    _controller.registerVisibleAlbum(widget.audioPath);
    _controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant MusicPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioPath != widget.audioPath) {
      _controller.unregisterVisibleAlbum(oldWidget.audioPath);
      _controller.registerVisibleAlbum(widget.audioPath);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.unregisterVisibleAlbum(widget.audioPath);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _playPause() async {
    await _controller.togglePlayPause(
      albumTitle: widget.albumTitle,
      audioPath: widget.audioPath,
      tracks: widget.tracks,
      selectedIndex: _localTrackIndex,
    );
  }

  Future<void> _playTrackAt(int index) async {
    setState(() {
      _localTrackIndex = index;
    });
    await _controller.playAlbumTrack(
      albumTitle: widget.albumTitle,
      audioPath: widget.audioPath,
      tracks: widget.tracks,
      trackIndex: index,
    );
  }

  Future<void> _next() async {
    final nextIdx = (_currentTrackIndex + 1) % widget.tracks.length;
    await _playTrackAt(nextIdx);
  }

  Future<void> _previous() async {
    final prevIdx =
        (_currentTrackIndex - 1 + widget.tracks.length) % widget.tracks.length;
    await _playTrackAt(prevIdx);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  String _cleanTrackName(String name) {
    return name.replaceAll('.wav', '').replaceAll('.m4a', '');
  }

  Widget _buildTextButton(
    String label,
    VoidCallback onTap, {
    bool isPrimary = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontFamily: 'JetBrainsMono',
            fontSize: 13,
            fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTerminalHeader(Color accentColor) {
    return Row(
      children: [
        Text(
          '~ > ',
          style: TextStyle(
            color: accentColor,
            fontFamily: 'JetBrainsMono',
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: MarqueeText(
            text:
                './${_cleanTrackName(widget.tracks[_currentTrackIndex]).replaceAll(' ', '_')}.sh',
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'JetBrainsMono',
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlsRow(Color accentColor) {
    final double maxMs = _duration.inMilliseconds.toDouble() > 0
        ? _duration.inMilliseconds.toDouble()
        : 1.0;
    final double effectivePosMs =
        (_dragValueMs ?? _position.inMilliseconds.toDouble()).clamp(0.0, maxMs);
    final Duration displayedPosition = _dragValueMs != null
        ? Duration(milliseconds: _dragValueMs!.toInt())
        : _position;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextButton(
                  _isPlaying ? '[ PAUSE ]' : '[ PLAY ]',
                  _playPause,
                  isPrimary: true,
                ),
                const SizedBox(width: 4),
                _buildTextButton('[ BACK ]', _previous),
                const SizedBox(width: 4),
                _buildTextButton('[ NEXT ]', _next),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                '${_formatDuration(displayedPosition)} / ${_formatDuration(_duration)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            activeTrackColor: accentColor,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
            thumbColor: accentColor,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            trackShape: const RectangularSliderTrackShape(),
          ),
          child: Slider(
            key: const Key('audio_scrubber'),
            value: effectivePosMs,
            max: maxMs,
            onChangeStart: (value) {
              if (_isThisAlbumActive) {
                setState(() {
                  _dragValueMs = value;
                });
              }
            },
            onChanged: (value) {
              if (_isThisAlbumActive) {
                setState(() {
                  _dragValueMs = value;
                });
                _controller.seek(Duration(milliseconds: value.toInt()));
              }
            },
            onChangeEnd: (value) {
              if (_isThisAlbumActive) {
                setState(() {
                  _dragValueMs = null;
                });
                _controller.seek(Duration(milliseconds: value.toInt()));
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTracklist(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '// AVAILABLE_TRACKS',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontFamily: 'JetBrainsMono',
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        ...widget.tracks.asMap().entries.map((entry) {
          final int index = entry.key;
          final String track = entry.value;
          final bool isCurrent = index == _currentTrackIndex;

          return InkWell(
            onTap: () => _playTrackAt(index),
            hoverColor: accentColor.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 6.0,
                horizontal: 4.0,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      isCurrent ? '->' : '  ',
                      style: TextStyle(
                        color: accentColor,
                        fontFamily: 'JetBrainsMono',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Flexible(
                    child: isCurrent
                        ? MarqueeText(
                            text: _cleanTrackName(track).toLowerCase(),
                            style: TextStyle(
                              color: accentColor,
                              fontFamily: 'JetBrainsMono',
                              fontSize: 13,
                            ),
                          )
                        : Text(
                            _cleanTrackName(track).toLowerCase(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontFamily: 'JetBrainsMono',
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                  if (isCurrent && _isPlaying) ...[
                    const SizedBox(width: 12),
                    _buildPlayingIndicator(accentColor),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color accentColor = kAccentColor;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTerminalHeader(accentColor),
          const SizedBox(height: 16),
          _buildControlsRow(accentColor),
          const SizedBox(height: 32),
          _buildTracklist(accentColor),
        ],
      ),
    );
  }

  Widget _buildPlayingIndicator(Color color) {
    return SizedBox(
      height: 10,
      width: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          3,
          (i) => _PlayingBar(color: color, delay: i * 200),
        ),
      ),
    );
  }
}

class _PlayingBar extends StatefulWidget {
  final Color color;
  final int delay;
  const _PlayingBar({required this.color, required this.delay});

  @override
  State<_PlayingBar> createState() => _PlayingBarState();
}

class _PlayingBarState extends State<_PlayingBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 2,
          height: 3 + (7 * _controller.value),
          color: widget.color,
        );
      },
    );
  }
}
