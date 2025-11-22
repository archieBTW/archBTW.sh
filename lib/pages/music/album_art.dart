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
          child: Image.asset(
            item.coverUrl,
          ),
        ),
      ),
    );
  }
}