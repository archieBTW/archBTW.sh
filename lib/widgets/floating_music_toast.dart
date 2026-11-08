import 'dart:ui';

import 'package:archbtw_sh/global/colors.dart';
import 'package:archbtw_sh/global/site_music_controller.dart';
import 'package:archbtw_sh/widgets/in_game_music_hud.dart';
import 'package:archbtw_sh/widgets/marquee_text.dart';
import 'package:flutter/material.dart';

class FloatingMusicToast extends StatelessWidget {
  const FloatingMusicToast({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = SiteMusicController.instance;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.shouldShowFloatingToast) {
          return const SizedBox.shrink();
        }

        final String trackTitle = cleanTrackTitle(controller.currentTrackName);
        final String albumTitle = controller.albumTitle ?? 'archbtw.sh';
        final bool isPlaying = controller.isPlaying;

        return SafeArea(
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 16,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Material(
                      key: const Key('floating_music_toast'),
                      color: const Color(0xEB0A0E17),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: kAccentColor.withValues(alpha: 0.75),
                          width: 1.2,
                        ),
                      ),
                      elevation: 10,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: kAccentColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: kAccentColor.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Icon(
                                isPlaying
                                    ? Icons.graphic_eq
                                    : Icons.music_note_outlined,
                                color: kAccentColor,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '// $albumTitle',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: kAccentColor.withValues(alpha: 0.8),
                                      fontFamily: 'JetBrainsMono',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  MarqueeText(
                                    text: trackTitle,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'JetBrainsMono',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            _ToastButton(
                              buttonKey: const Key('toast_prev_button'),
                              tooltip: 'Previous Track',
                              icon: Icons.skip_previous_rounded,
                              onTap: controller.previous,
                            ),
                            const SizedBox(width: 2),
                            _ToastButton(
                              buttonKey: const Key('toast_play_pause_button'),
                              tooltip: isPlaying ? 'Pause' : 'Play',
                              icon: isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              isPrimary: true,
                              onTap: controller.togglePlayPause,
                            ),
                            const SizedBox(width: 2),
                            _ToastButton(
                              buttonKey: const Key('toast_next_button'),
                              tooltip: 'Next Track',
                              icon: Icons.skip_next_rounded,
                              onTap: controller.next,
                            ),
                            const SizedBox(width: 4),
                            _ToastButton(
                              buttonKey: const Key('toast_close_button'),
                              tooltip: 'Stop & Close',
                              icon: Icons.close_rounded,
                              iconSize: 15,
                              onTap: controller.stopAndDismiss,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ToastButton extends StatelessWidget {
  final Key buttonKey;
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final double iconSize;

  const _ToastButton({
    required this.buttonKey,
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: buttonKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: isPrimary
              ? kAccentColor.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isPrimary
                ? kAccentColor.withValues(alpha: 0.85)
                : Colors.white24,
          ),
        ),
        child: Icon(
          icon,
          size: iconSize,
          color: isPrimary ? kAccentColor : Colors.white,
        ),
      ),
    );
  }
}
