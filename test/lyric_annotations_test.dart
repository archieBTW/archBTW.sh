import 'package:archbtw_sh/pages/music/album_detail_page.dart';
import 'package:archbtw_sh/pages/music/album_item_list.dart';
import 'package:archbtw_sh/pages/music/lyric_annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Lyric Annotations Coverage', () {
    test(
      'every track title and every lyric line across all unlocked albums has a dedicated annotation',
      () {
        final unlockedAlbums = albumItems
            .where((a) => !a.isLocked && a.lyrics.trim().isNotEmpty)
            .toList();

        expect(unlockedAlbums.length, 3);

        final List<String> missingTracks = [];
        final List<String> missingLines = [];
        int totalTracksChecked = 0;
        int totalLinesChecked = 0;

        for (final album in unlockedAlbums) {
          final parsed = parseAlbumLyrics(album.lyrics);
          expect(
            parsed.tracks,
            isNotEmpty,
            reason: 'Expected tracks for album ${album.title}',
          );

          for (final track in parsed.tracks) {
            totalTracksChecked++;
            final breakdown = getTrackBreakdown(album.title, track.title);
            if (breakdown == null || breakdown.overview.trim().isEmpty) {
              missingTracks.add('${album.title} -> [${track.title}]');
            }

            for (final row in track.rows) {
              if (row.isStanzaBreak || row.item == null) continue;
              totalLinesChecked++;
              final line = row.item!.text;
              final annotation = getLineAnnotation(
                album.title,
                track.title,
                line,
              );
              if (annotation == null || annotation.summary.trim().isEmpty) {
                missingLines.add(
                  '${album.title} -> [${track.title}] -> "$line"',
                );
              }
            }
          }
        }

        expect(
          missingTracks,
          isEmpty,
          reason: 'Missing track breakdowns:\n${missingTracks.join('\n')}',
        );
        expect(
          missingLines,
          isEmpty,
          reason: 'Missing line annotations:\n${missingLines.join('\n')}',
        );
        expect(totalTracksChecked, 32);
        expect(totalLinesChecked, greaterThan(700));
      },
    );
  });

  group('AnnotatedLyricsSection Interactive UI', () {
    testWidgets(
      'desktop displays side-by-side Genius annotation rail for track titles and lyric lines with prev/next/close',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final santasCookies = albumItems.firstWhere(
          (a) => a.title == "santa's cookies",
        );

        await tester.pumpWidget(
          MaterialApp(
            home: AlbumDetailPage(item: santasCookies),
          ),
        );

        // Expand lyrics
        await tester.ensureVisible(find.text('lyrics.expand();'));
        await tester.pump();
        await tester.tap(find.text('lyrics.expand();'));
        await tester.pump(const Duration(milliseconds: 300));

        // Header bar with track skip chips is removed; guide card is still shown
        expect(find.text('// LYRIC_ANNOTATIONS'), findsNothing);
        expect(find.byKey(const Key('jump_track_chip_0')), findsNothing);
        expect(find.byKey(const Key('annotation_guide_card')), findsOneWidget);
        expect(find.byKey(const Key('annotation_card')), findsNothing);

        // Click first track title -> opens TRACK BREAKDOWN
        await tester.ensureVisible(find.byKey(const Key('lyric_track_0')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('lyric_track_0')));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(const Key('annotation_card')), findsOneWidget);
        expect(find.text('TRACK BREAKDOWN'), findsOneWidget);
        expect(find.textContaining('late-stage Christmas consumerism'), findsOneWidget);

        // Click first lyric line -> switches to LYRIC ANNOTATION
        await tester.ensureVisible(find.byKey(const Key('lyric_line_1')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('lyric_line_1')));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('LYRIC ANNOTATION'), findsOneWidget);
        expect(find.text('LINE 1 / 38'), findsOneWidget);
        expect(find.textContaining('Triple-meaning opener on "lit"'), findsOneWidget);

        // Step forward with [ next → ]
        await tester.ensureVisible(find.byKey(const Key('annotation_next_button')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('annotation_next_button')));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('LINE 2 / 38'), findsOneWidget);
        expect(find.textContaining('Inverts "mistletoe"'), findsOneWidget);

        // Step backward with [ ← prev ]
        await tester.ensureVisible(find.byKey(const Key('annotation_prev_button')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('annotation_prev_button')));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('LINE 1 / 38'), findsOneWidget);

        // Click track breadcrumb to jump back to track overview
        await tester.ensureVisible(
          find.byKey(const Key('annotation_track_breadcrumb')),
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('annotation_track_breadcrumb')));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('TRACK BREAKDOWN'), findsOneWidget);

        // Close card via [ x ]
        await tester.ensureVisible(
          find.byKey(const Key('annotation_close_button')),
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('annotation_close_button')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const Key('annotation_card')), findsNothing);
        expect(find.byKey(const Key('annotation_guide_card')), findsOneWidget);

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'mobile opens inline expandable Genius annotation cards for tracks and lines without overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(430, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final lifesLemons = albumItems.firstWhere(
          (a) => a.title == "life's lemons",
        );

        await tester.pumpWidget(
          MaterialApp(
            home: AlbumDetailPage(item: lifesLemons),
          ),
        );

        await tester.ensureVisible(find.text('lyrics.expand();'));
        await tester.pump();
        await tester.tap(find.text('lyrics.expand();'));
        await tester.pump(const Duration(milliseconds: 300));

        // Tap track 0 header
        await tester.ensureVisible(find.byKey(const Key('lyric_track_0')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('lyric_track_0')));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(const Key('annotation_card')), findsOneWidget);
        expect(find.text('TRACK BREAKDOWN'), findsOneWidget);

        // Tap a lyric line directly -> moves inline card under that line
        await tester.ensureVisible(find.byKey(const Key('lyric_line_1')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('lyric_line_1')));
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byKey(const Key('annotation_card')), findsOneWidget);
        expect(find.text('LYRIC ANNOTATION'), findsOneWidget);
        expect(find.textContaining('SoundCloud rap days'), findsOneWidget);

        // Tap the same lyric line again -> toggles closed
        await tester.ensureVisible(find.byKey(const Key('lyric_line_1')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('lyric_line_1')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const Key('annotation_card')), findsNothing);

        expect(tester.takeException(), isNull);
      },
    );
  });
}
