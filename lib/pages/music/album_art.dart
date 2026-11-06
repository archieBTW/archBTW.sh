import 'package:archbtw_sh/pages/music/album_item.dart';
import 'package:flutter/material.dart';

class AlbumArt extends StatelessWidget {
  final AlbumItem item;
  const AlbumArt({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Hero(
        tag: item.coverUrl,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(item.coverUrl),
              if (item.isLocked) ...[
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
