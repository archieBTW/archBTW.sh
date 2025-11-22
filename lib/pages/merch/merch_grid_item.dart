import 'dart:ui';

import 'package:archbtw_sh/global/colors.dart';
import 'package:archbtw_sh/global/helpers.dart';
import 'package:archbtw_sh/pages/merch/merch_item.dart';
import 'package:archbtw_sh/widgets/loading_waveform.dart';
import 'package:flutter/material.dart';

class MerchGridItem extends StatelessWidget {
  final MerchItem item;
  const MerchGridItem({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => openUrl(item.productUrl),
      borderRadius: BorderRadius.circular(12.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                decoration: const BoxDecoration(color: Colors.transparent),
              ),
            ),
            Card(
              color: Colors.white.withOpacity(0.05),
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Image.asset(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      // Use frameBuilder to show loader while decoding/loading
                      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded || frame != null) {
                          return child;
                        }
                        return Container(
                          color: Colors.white.withOpacity(0.02),
                          child: const Center(
                            // Scaled down version of the loader for grid items
                            child: WaveformLoader(height: 25, barWidth: 3),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: kTextColor,
                              size: 50,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    height: 85.0,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              color: kTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              fontFamily: 'JetBrainsMono',
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.price,
                            style: const TextStyle(
                              color: kAccentColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'JetBrainsMono',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}