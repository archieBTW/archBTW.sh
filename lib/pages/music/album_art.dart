import 'package:archbtw_sh/pages/music/album_item.dart';
import 'package:flutter/material.dart';

class AlbumArt extends StatelessWidget {
  final AlbumItem item;
  const AlbumArt({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480.0, maxHeight: 480.0),
          child: AspectRatio(
            aspectRatio: 1.0,
            child: Hero(
              tag: item.coverUrl,
              createRectTween: (begin, end) =>
                  MaterialRectArcTween(begin: begin, end: end),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.center,
                  children: [
                    Image.asset(item.coverUrl, fit: BoxFit.cover),
                    if (item.isLocked) ...[
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.35),
                        ),
                      ),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white24,
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.lock_outline,
                            color: Colors.white,
                            size: 36,
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
      ),
    );
  }
}
