import 'package:archbtw_sh/global/colors.dart';
import 'package:archbtw_sh/widgets/marquee_text.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

void configureBackgroundAudioContext() {
  try {
    AudioPlayer.global.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
        ),
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
      ),
    );
  } catch (_) {
    // Ignore on platforms or test environments where AudioContext isn't supported
  }
}

String cleanTrackTitle(String filename) {
  return filename
      .replaceAll('.wav', '')
      .replaceAll('.m4a', '')
      .replaceAll('_', ' ');
}

class InGameMusicHud extends StatelessWidget {
  final String currentTrack;
  final bool isPlaying;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPlayPause;
  final Color accentColor;

  const InGameMusicHud({
    super.key,
    required this.currentTrack,
    required this.isPlaying,
    required this.onPrevious,
    required this.onNext,
    required this.onPlayPause,
    this.accentColor = kAccentColor,
  });

  @override
  Widget build(BuildContext context) {
    final String displayTitle = cleanTrackTitle(currentTrack);

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        border: Border(
          bottom: BorderSide(
            color: accentColor.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.music_note,
            color: accentColor,
            size: 15,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: MarqueeText(
              text: displayTitle.isEmpty ? 'loading track...' : displayTitle,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _HudIconButton(
            key: const Key('music_prev_button'),
            tooltip: 'Previous Track',
            icon: Icons.skip_previous,
            color: Colors.white70,
            onTap: onPrevious,
          ),
          const SizedBox(width: 2),
          _HudIconButton(
            key: const Key('music_play_pause_button'),
            tooltip: isPlaying ? 'Pause' : 'Play',
            icon: isPlaying ? Icons.pause : Icons.play_arrow,
            color: accentColor,
            onTap: onPlayPause,
          ),
          const SizedBox(width: 2),
          _HudIconButton(
            key: const Key('music_next_button'),
            tooltip: 'Next Track',
            icon: Icons.skip_next,
            color: Colors.white70,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class _HudIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HudIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

