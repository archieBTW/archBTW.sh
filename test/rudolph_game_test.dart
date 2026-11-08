import 'package:archbtw_sh/games/blubber_game.dart';
import 'package:archbtw_sh/games/lemon_game.dart';
import 'package:archbtw_sh/games/santa_game.dart';
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
      expect(LemonItemType.values.length, 6);
      expect(LemonItemType.values, contains(LemonItemType.lemon));

      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    },
  );
}
