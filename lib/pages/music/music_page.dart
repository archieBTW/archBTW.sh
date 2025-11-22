import 'package:archbtw_sh/pages/music/album_grid_item.dart';
import 'package:archbtw_sh/pages/music/album_item_list.dart';
import 'package:flutter/material.dart';

class MusicPage extends StatelessWidget {
  const MusicPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GridView.builder(
        padding: const EdgeInsets.all(16.0),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 250.0,
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
          childAspectRatio: 0.80,
        ),
        itemCount: albumItems.length,
        itemBuilder: (context, index) {
          return AlbumGridItem(item: albumItems[index]);
        },
      ),
    );
  }
}
