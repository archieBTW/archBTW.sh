import 'dart:async';
import 'package:archbtw_sh/global/colors.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class MusicPlayer extends StatefulWidget {
  final List<String> tracks;
  final String audioPath;
  final bool isDesktop;

  const MusicPlayer({
    super.key,
    required this.tracks,
    required this.audioPath,
    this.isDesktop = true,
  });

  @override
  State<MusicPlayer> createState() => _MusicPlayerState();
}

class _MusicPlayerState extends State<MusicPlayer> {
  late AudioPlayer _audioPlayer;
  int _currentTrackIndex = 0;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _setupAudioListeners();
  }

  void _setupAudioListeners() {
    _durationSubscription = _audioPlayer.onDurationChanged.listen((d) {
      setState(() => _duration = d);
    });

    _positionSubscription = _audioPlayer.onPositionChanged.listen((p) {
      setState(() => _position = p);
    });

    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      _next();
    });

    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((
      state,
    ) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (_position == Duration.zero) {
        await _playTrack();
      } else {
        await _audioPlayer.resume();
      }
    }
  }

  Future<void> _playTrack() async {
    final track = widget.tracks[_currentTrackIndex];
    final fullPath = '${widget.audioPath}$track';
    await _audioPlayer.play(AssetSource(fullPath));
  }

  Future<void> _next() async {
    setState(() {
      _currentTrackIndex = (_currentTrackIndex + 1) % widget.tracks.length;
    });
    await _playTrack();
  }

  Future<void> _previous() async {
    setState(() {
      _currentTrackIndex =
          (_currentTrackIndex - 1 + widget.tracks.length) %
          widget.tracks.length;
    });
    await _playTrack();
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
          child: Text(
            './${_cleanTrackName(widget.tracks[_currentTrackIndex]).replaceAll(' ', '_')}.sh',
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'JetBrainsMono',
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildControlsRow(Color accentColor) {
    return Row(
      children: [
        _buildTextButton(
          _isPlaying ? '[ PAUSE ]' : '[ PLAY ]',
          _playPause,
          isPrimary: true,
        ),
        const SizedBox(width: 8),
        _buildTextButton('[ BACK ]', _previous),
        const SizedBox(width: 4),
        _buildTextButton('[ NEXT ]', _next),
        const SizedBox(width: 16),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 1,
              activeTrackColor: accentColor,
              inactiveTrackColor: Colors.white.withOpacity(0.1),
              thumbColor: accentColor,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
            ),
            child: Slider(
              value: _position.inMilliseconds.toDouble(),
              max: _duration.inMilliseconds.toDouble() > 0
                  ? _duration.inMilliseconds.toDouble()
                  : 1.0,
              onChanged: (value) {
                _audioPlayer.seek(Duration(milliseconds: value.toInt()));
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontFamily: 'JetBrainsMono',
            fontSize: 12,
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
            color: Colors.white.withOpacity(0.3),
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
            onTap: () {
              setState(() => _currentTrackIndex = index);
              _playTrack();
            },
            hoverColor: accentColor.withOpacity(0.05),
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
                  Text(
                    _cleanTrackName(track).toLowerCase(),
                    style: TextStyle(
                      color: isCurrent
                          ? accentColor
                          : Colors.white.withOpacity(0.7),
                      fontFamily: 'JetBrainsMono',
                      fontSize: 13,
                      decoration: isCurrent ? TextDecoration.none : null,
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
        }).toList(),
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
