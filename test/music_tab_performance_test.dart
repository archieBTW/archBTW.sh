import 'package:archbtw_sh/main.dart';
import 'package:archbtw_sh/pages/music/album_art.dart';
import 'package:archbtw_sh/pages/music/album_detail_page.dart';
import 'package:archbtw_sh/pages/music/album_grid_item.dart';
import 'package:archbtw_sh/pages/music/album_item_list.dart';
import 'package:archbtw_sh/pages/music/music_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Music tab loads immediately upon tapping navigation link', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const ArchWebsite());
    // On initial mount before 300ms, Home is loaded, Music is not yet loaded in background
    expect(find.byType(MusicPage), findsNothing);

    // Tap Music navigation tab ('music' text link)
    final musicNav = find.text('music');
    expect(musicNav, findsWidgets);
    await tester.tap(musicNav.first);
    await tester.pump();

    // MusicPage is immediately loaded into the widget tree without waiting for background stagger
    expect(find.byType(MusicPage), findsOneWidget);

    // Drain remaining staggered load timers
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets(
    'AlbumGridItem Hero transition to AlbumDetailPage matches tag and rect tween',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testItem = albumItems.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: AlbumGridItem(item: testItem),
            ),
          ),
        ),
      );

      // Verify Hero exists in AlbumGridItem
      final heroFinder = find.byType(Hero);
      expect(heroFinder, findsOneWidget);
      final Hero gridHero = tester.widget<Hero>(heroFinder);
      expect(gridHero.tag, equals(testItem.coverUrl));
      expect(gridHero.createRectTween, isNotNull);

      // Tap on grid item to trigger navigation
      await tester.tap(find.byType(AlbumGridItem));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Navigated to AlbumDetailPage during hero flight
      expect(find.byType(AlbumDetailPage), findsOneWidget);

      // Advance past transition duration (400ms)
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AlbumDetailPage), findsOneWidget);

      // Verify AlbumArt in AlbumDetailPage has matching Hero tag and rect tween
      final detailHero = tester.widget<Hero>(
        find.descendant(of: find.byType(AlbumArt), matching: find.byType(Hero)),
      );
      expect(detailHero.tag, equals(testItem.coverUrl));
      expect(detailHero.createRectTween, isNotNull);
    },
  );
}
