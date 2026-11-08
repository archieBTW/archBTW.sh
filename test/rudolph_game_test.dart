import 'package:archbtw_sh/games/blubber_game.dart';
import 'package:archbtw_sh/games/lemon_game.dart';
import 'package:archbtw_sh/games/santa_game.dart';
import 'package:archbtw_sh/global/site_music_controller.dart';
import 'package:archbtw_sh/pages/music/album_detail_page.dart';
import 'package:archbtw_sh/pages/music/album_grid_item.dart';
import 'package:archbtw_sh/pages/music/album_item_list.dart';
import 'package:archbtw_sh/widgets/floating_music_toast.dart';
import 'package:archbtw_sh/widgets/in_game_music_hud.dart';
import 'package:archbtw_sh/widgets/marquee_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Rudolph shoot-em-up replaces holiday_consumerism.sh without lyric ticker and supports touch & keyboard controls',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SantasInvadersGame(),
        ),
      );

      // Verify new title replaces holiday_consumerism.sh
      expect(find.text('rudolph_spoke.sh'), findsOneWidget);
      expect(find.text('holiday_consumerism.sh'), findsNothing);

      // Verify HUD is shown and lyric ticker is removed
      expect(find.text('POINTS: 0'), findsOneWidget);
      expect(find.textContaining('MARKED IN CRIMSON: 0'), findsOneWidget);
      expect(
        find.textContaining('The moon grins down onto the snowcapped trees.'),
        findsNothing,
      );

      // Verify Contra-style touch controls are present
      expect(find.byKey(const Key('virtual_joystick')), findsOneWidget);
      expect(find.byKey(const Key('jump_button')), findsOneWidget);
      expect(find.byKey(const Key('shoot_button')), findsOneWidget);

      // Verify InGameMusicHud and skip/back controls are present
      expect(find.byType(InGameMusicHud), findsOneWidget);
      expect(find.byKey(const Key('music_prev_button')), findsOneWidget);
      expect(find.byKey(const Key('music_play_pause_button')), findsOneWidget);
      expect(find.byKey(const Key('music_next_button')), findsOneWidget);
      expect(find.text('rudolph spoke in class today'), findsWidgets);

      // Tap next track button and verify track title updates
      await tester.tap(find.byKey(const Key('music_next_button')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('who you calling a ho ho'), findsWidgets);

      // Tap previous track button and verify track returns
      await tester.tap(find.byKey(const Key('music_prev_button')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('rudolph spoke in class today'), findsWidgets);

      // Test touch JUMP button and SHOOT button
      await tester.tap(find.byKey(const Key('jump_button')));
      await tester.pump(const Duration(milliseconds: 50));

      final TestGesture shootGesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('shoot_button'))),
      );
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await shootGesture.up();

      // Test keyboard movement and shooting
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyJ);
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyJ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'WhaleGame 3D hole-style krill & item swallowing game renders and responds to touch drag and boost',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WhaleGame(),
        ),
      );

      expect(find.text('floppy_whale.sh'), findsOneWidget);
      expect(find.textContaining('SCORE:'), findsOneWidget);
      expect(find.textContaining('CLASS: KRILL GULPER (LVL 1)'), findsOneWidget);
      expect(find.textContaining('GOAL: 0/10'), findsOneWidget);
      expect(find.byKey(const Key('spout_boost_button')), findsOneWidget);

      // Simulate touch drag steering across the 3D ocean
      final TestGesture drag = await tester.startGesture(
        const Offset(300, 300),
      );
      await drag.moveBy(const Offset(50, -40));
      for (int i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await drag.up();

      // Trigger spout boost button
      await tester.tap(find.byKey(const Key('spout_boost_button')));
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'LemonsGame renders cartoon lyric items (lemons, pills, elixir, candle, coffee, cherry 7) with puzzle logic',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LemonsGame(),
        ),
      );

      expect(find.textContaining('SCORE: 0'), findsOneWidget);
      expect(find.byTooltip('Shuffle Board'), findsOneWidget);
      expect(find.byType(InGameMusicHud), findsOneWidget);
      expect(find.byType(MarqueeText), findsOneWidget);
      expect(LemonItemType.values.length, 6);
      expect(LemonItemType.values, contains(LemonItemType.lemon));

      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'AlbumGridItem does not show play game icon while AlbumDetailPage shows launch game button and persists music via FloatingMusicToast on back navigation',
    (WidgetTester tester) async {
      SiteMusicController.instance.resetForTest();
      addTearDown(() => SiteMusicController.instance.resetForTest());

      final blubber = albumItems.firstWhere((a) => a.title == 'blubber');

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => Stack(
            children: [
              if (child != null) child,
              const FloatingMusicToast(),
            ],
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                height: 340,
                child: AlbumGridItem(item: blubber),
              ),
            ),
          ),
        ),
      );

      // AlbumGridItem on the album list screen should NOT have the play game button/icon
      expect(find.byIcon(Icons.sports_esports), findsNothing);
      expect(find.text('PLAY GAME'), findsNothing);

      // Tap AlbumGridItem to navigate to AlbumDetailPage
      await tester.tap(find.byType(AlbumGridItem));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // AlbumDetailPage SHOULD have the prominent launch game button
      expect(find.byKey(const Key('launch_game_button')), findsOneWidget);
      expect(find.text('PLAY: floppy_whale.sh'), findsOneWidget);

      // Start playing music on AlbumDetailPage
      await tester.tap(find.text('[ PLAY ]'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(SiteMusicController.instance.isPlaying, isTrue);
      // Toast is hidden while still on this album's detail page
      expect(find.byKey(const Key('floating_music_toast')), findsNothing);

      // Navigate back to the rest of the site
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // Music continues playing and the styled FloatingMusicToast is shown
      expect(SiteMusicController.instance.isPlaying, isTrue);
      expect(find.byKey(const Key('floating_music_toast')), findsOneWidget);
      expect(find.text('why is it spicy'), findsWidgets);

      // Skip to next track from the toast
      await tester.tap(find.byKey(const Key('toast_next_button')));
      await tester.pump();
      expect(find.text('whale mail'), findsWidgets);

      // Pause from the toast
      await tester.tap(find.byKey(const Key('toast_play_pause_button')));
      await tester.pump();
      expect(SiteMusicController.instance.isPlaying, isFalse);
    },
  );
}
