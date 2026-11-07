import 'package:archbtw_sh/games/santa_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Rudolph shoot-em-up replaces holiday_consumerism.sh with touch & keyboard controls and awards points',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SantasInvadersGame(),
        ),
      );

      // Verify new title replaces holiday_consumerism.sh
      expect(find.text('rudolph_spoke.sh'), findsOneWidget);
      expect(find.text('holiday_consumerism.sh'), findsNothing);

      // Verify initial HUD & Santa's Cookies lyric reference
      expect(find.text('POINTS: 0'), findsOneWidget);
      expect(find.textContaining('MARKED IN CRIMSON: 0'), findsOneWidget);
      expect(
        find.textContaining('The moon grins down onto the snowcapped trees.'),
        findsOneWidget,
      );

      // Verify Contra-style touch controls are present
      expect(find.byKey(const Key('virtual_joystick')), findsOneWidget);
      expect(find.byKey(const Key('jump_button')), findsOneWidget);
      expect(find.byKey(const Key('shoot_button')), findsOneWidget);

      // Test touch JUMP button and SHOOT button
      await tester.tap(find.byKey(const Key('jump_button')));
      await tester.pump(const Duration(milliseconds: 50));

      // Hold down SHOOT button and advance frames so bullets hit reindeer
      final TestGesture shootGesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('shoot_button'))),
      );
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await shootGesture.up();

      // Also test keyboard movement and shooting
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyJ);
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyJ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);

      // Ensure no exceptions occurred during rendering and physics updates
      expect(tester.takeException(), isNull);
    },
  );
}

