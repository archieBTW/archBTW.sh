import 'package:archbtw_sh/games/gamepad_poller.dart';
import 'package:archbtw_sh/games/okc_beat_em_up_game.dart';
import 'package:archbtw_sh/pages/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomePage Game Link', () {
    testWidgets(
      'Bottom row of HomePage displays link to start OkcBeatEmUpGame and navigates on tap',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: HomePage()),
          ),
        );

        final Finder gameBtn = find.byKey(const Key('okc_game_button'));
        expect(gameBtn, findsOneWidget);

        await tester.tap(gameBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(OkcBeatEmUpGame), findsOneWidget);
        expect(find.text('okc_dead_chord.sh'), findsOneWidget);
      },
    );
  });

  group('Downtown OKC 8-Bit NES Beat-Em-Up / Platformer Gameplay', () {
    testWidgets(
      'Initializes Downtown OKC level with Tortie Cat at start, Cat Food at end, Goose, Zombies, and all 4 Powerups',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: OkcBeatEmUpGame(),
          ),
        );

        final OkcBeatEmUpGameState state =
            tester.state<OkcBeatEmUpGameState>(find.byType(OkcBeatEmUpGame));

        expect(state.level, equals(1));
        expect(state.currentDistrict, contains('OKC'));
        // Tortie cat at beginning of level, cat food at end of level
        expect(state.tortieCatX, lessThan(200.0));
        expect(state.catFoodX, greaterThan(2000.0));

        // Zombies are spawned
        expect(state.zombies, isNotEmpty);

        // Verify all 4 powerup types exist in the generated map: pill, guitar, spider, pigeon
        final Set<OkcPowerupType> spawnedTypes =
            state.powerups.map((p) => p.type).toSet();
        expect(spawnedTypes, contains(OkcPowerupType.pill));
        expect(spawnedTypes, contains(OkcPowerupType.guitar));
        expect(spawnedTypes, contains(OkcPowerupType.spider));
        expect(spawnedTypes, contains(OkcPowerupType.pigeon));
      },
    );

    testWidgets(
      'Shuffles exclusively through life\'s lemons and blubber tracks and scales up on 1080p desktop screens',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: OkcBeatEmUpGame(),
          ),
        );

        final OkcBeatEmUpGameState state =
            tester.state<OkcBeatEmUpGameState>(find.byType(OkcBeatEmUpGame));

        // Verify playlist has all 13 life's lemons + 15 blubber tracks (28 total) and no interject tracks
        expect(state.playlist.length, equals(28));
        expect(
          state.playlist.every(
            (t) => t.startsWith('lemons/') || t.startsWith('blubber/'),
          ),
          isTrue,
        );
        expect(
          state.playlist.where((t) => t.startsWith('lemons/')).length,
          equals(13),
        );
        expect(
          state.playlist.where((t) => t.startsWith('blubber/')).length,
          equals(15),
        );

        // Verify 1080p desktop viewport scales up the 8-bit world (> 2.0x)
        expect(state.worldScale, greaterThan(2.0));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Goose (white pitbull/corgi mix) can be ridden like Yoshi and absorbs zombie hits',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: OkcBeatEmUpGame(),
          ),
        );

        final OkcBeatEmUpGameState state =
            tester.state<OkcBeatEmUpGameState>(find.byType(OkcBeatEmUpGame));

        expect(state.isRidingGoose, isFalse);
        state.mountGoose();
        await tester.pump();
        expect(state.isRidingGoose, isTrue);
        expect(find.text('MOUNT: GOOSE'), findsOneWidget);

        // Place a zombie directly on the player to trigger contact damage while riding Goose
        final int initialHp = state.health;
        state.zombies.first.x = state.playerX;
        state.zombies.first.y = state.playerY;
        state.zombies.first.hurtTimer = 0.0;
        state.zombies.first.attackCooldown = 0.0;

        await tester.pump(const Duration(milliseconds: 50));

        // Goose absorbed the hit like Yoshi: player lost 0 HP and dismounted Goose!
        expect(state.health, equals(initialHp));
        expect(state.isRidingGoose, isFalse);
      },
    );

    testWidgets(
      'Powerups work: Pills heal, Guitar equips chord attacks, Spider enables web-swing, Pigeons give +1 life',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: OkcBeatEmUpGame(),
          ),
        );

        final OkcBeatEmUpGameState state =
            tester.state<OkcBeatEmUpGameState>(find.byType(OkcBeatEmUpGame));

        // 1. Pigeon gives +1 life
        final int initialLives = state.lives;
        state.collectPowerup(OkcPowerupType.pigeon);
        await tester.pump();
        expect(state.lives, equals(initialLives + 1));

        // 2. Guitar equips as "fireflower" and fires power chords on attack
        expect(state.hasGuitar, isFalse);
        state.collectPowerup(OkcPowerupType.guitar);
        await tester.pump();
        expect(state.hasGuitar, isTrue);
        expect(find.text('GUITAR: CHORDS'), findsOneWidget);

        state.triggerChordAttack();
        await tester.pump(const Duration(milliseconds: 50));
        expect(state.chordProjectiles, isNotEmpty);

        // 3. Spider powerup enables swinging from webs
        expect(state.hasSpiderPower, isFalse);
        state.collectPowerup(OkcPowerupType.spider);
        await tester.pump();
        expect(state.hasSpiderPower, isTrue);
        expect(find.text('SPIDER: WEB'), findsOneWidget);

        state.triggerWebSwing();
        await tester.pump(const Duration(milliseconds: 50));
        expect(state.isWebSwinging, isTrue);
        state.releaseWebSwing(launchBoost: true);
        await tester.pump();
        expect(state.isWebSwinging, isFalse);

        // 4. Pill restores health
        state.collectPowerup(OkcPowerupType.pill);
        await tester.pump();
        expect(state.health, equals(state.maxHealth));
      },
    );

    testWidgets(
      'Punch and Kick attacks damage zombies, and completing a level generates a new Downtown OKC map',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: OkcBeatEmUpGame(),
          ),
        );

        final OkcBeatEmUpGameState state =
            tester.state<OkcBeatEmUpGameState>(find.byType(OkcBeatEmUpGame));

        // Position a zombie in front of archBTW and test Punch & Kick
        final OkcZombie targetZombie = state.zombies.first;
        final int startHp = targetZombie.hp;
        targetZombie.x = state.playerX + 35.0;
        targetZombie.y = state.playerY;

        state.triggerPunch();
        await tester.pump(const Duration(milliseconds: 300));
        expect(targetZombie.hp, lessThan(startHp));

        targetZombie.x = state.playerX + 40.0;
        targetZombie.y = state.playerY;
        final int afterPunchHp = targetZombie.hp;
        state.triggerKick();
        await tester.pump(const Duration(milliseconds: 300));
        expect(targetZombie.hp, lessThan(afterPunchHp));

        // Completing the level feeds the Tortie Cat and generates a brand-new map
        final int level1Seed = state.mapSeed;
        final int level1GenCount = state.mapGenerationCount;

        state.completeCurrentLevel();
        await tester.pump();

        expect(state.level, equals(2));
        expect(state.mapGenerationCount, equals(level1GenCount + 1));
        expect(state.mapSeed, isNot(equals(level1Seed)));
      },
    );

    testWidgets(
      'Supports mobile touch joystick/buttons and desktop keyboard + controller input',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: OkcBeatEmUpGame(),
          ),
        );

        final OkcBeatEmUpGameState state =
            tester.state<OkcBeatEmUpGameState>(find.byType(OkcBeatEmUpGame));

        // Verify touch controls exist and respond cleanly
        expect(find.byKey(const Key('virtual_joystick')), findsOneWidget);
        expect(find.byKey(const Key('punch_button')), findsOneWidget);
        expect(find.byKey(const Key('kick_button')), findsOneWidget);
        expect(find.byKey(const Key('jump_button')), findsOneWidget);
        expect(find.byKey(const Key('chord_button')), findsOneWidget);
        expect(find.byKey(const Key('web_button')), findsOneWidget);

        await tester.tap(find.byKey(const Key('punch_button')));
        await tester.pump(const Duration(milliseconds: 250));
        await tester.tap(find.byKey(const Key('kick_button')));
        await tester.pump(const Duration(milliseconds: 250));
        await tester.tap(find.byKey(const Key('jump_button')));
        await tester.pump(const Duration(milliseconds: 50));

        // Test virtual joystick drag
        final TestGesture joyDrag = await tester.startGesture(
          tester.getCenter(find.byKey(const Key('virtual_joystick'))),
        );
        await joyDrag.moveBy(const Offset(40, 0));
        await tester.pump(const Duration(milliseconds: 100));
        await joyDrag.up();
        await tester.pump();

        // Test keyboard controls (Move, Jump, Punch, Kick)
        final double xBeforeKey = state.playerX;
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 30));
        }
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
        expect(state.playerX, greaterThan(xBeforeKey));

        // Test desktop controller (Gamepad) input
        final double xBeforePad = state.playerX;
        state.applyControllerInput(
          const GamepadInputState(
            connected: true,
            id: 'Xbox Wireless Controller',
            axisX: 1.0,
            jumpPressed: true,
            punchPressed: true,
          ),
        );
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 30));
        }
        expect(state.isControllerConnected, isTrue);
        expect(state.playerX, greaterThan(xBeforePad));

        expect(tester.takeException(), isNull);
      },
    );
  });
}
