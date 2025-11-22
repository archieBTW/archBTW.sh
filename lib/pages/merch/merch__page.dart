import 'package:archbtw_sh/global/colors.dart';
import 'package:archbtw_sh/pages/merch/merch_grid_item.dart';
import 'package:archbtw_sh/pages/merch/merch_item_list.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const String kStoreUrl = 'https://www.teepublic.com/user/archbtw';

class MerchPage extends StatelessWidget {
  const MerchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 250.0,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
                childAspectRatio: 0.75,
              ),
              itemCount: merchItems.length,
              itemBuilder: (context, index) {
                return MerchGridItem(item: merchItems[index]);
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 32.0),
              child: Center(
                child: TextButton(
                  onPressed: () => launchUrl(Uri.parse(kStoreUrl)),
                  style: TextButton.styleFrom(
                    foregroundColor: kAccentColor,
                    textStyle: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
                  child: const Text('View More on TeePublic'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

