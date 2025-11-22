import 'package:archbtw_sh/global/colors.dart';
import 'package:archbtw_sh/pages/music/album_art.dart';
import 'package:archbtw_sh/pages/music/album_details.dart';
import 'package:archbtw_sh/pages/music/album_item.dart';
import 'package:flutter/material.dart';

class AlbumDetailPage extends StatelessWidget {
  final AlbumItem item;
  const AlbumDetailPage({super.key, required this.item});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: kTextColor),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isDesktop = constraints.maxWidth > 800.0;
  
                final albumArt = AlbumArt(item: item);
                final albumDetails = AlbumDetails(item: item, isDesktop: isDesktop,);
  
                if (isDesktop) {
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: albumArt),
                        const SizedBox(width: 32.0),
                        Expanded(flex: 3, child: albumDetails),
                      ],
                    ),
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      albumArt,
                      albumDetails,
                    ],
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}