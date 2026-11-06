import 'package:archbtw_sh/pages/home/home_page.dart';
import 'package:archbtw_sh/pages/music/album_detail_page.dart';
import 'package:archbtw_sh/pages/music/album_grid_item.dart';
import 'package:archbtw_sh/pages/music/album_item_list.dart';
import 'package:archbtw_sh/pages/overheat/overheat_page.dart';
import 'package:archbtw_sh/widgets/social_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

void main() {
  group('Locked Album third-degree', () {
    test('albumItems contains locked third-degree album with fire.png cover', () {
      final thirdDegree = albumItems.firstWhere(
        (a) => a.title == 'third-degree',
        orElse: () => throw Exception('third-degree album not found'),
      );

      expect(thirdDegree.coverUrl, 'assets/images/fire.png');
      expect(thirdDegree.isLocked, isTrue);
    });

    testWidgets('AlbumGridItem displays locked state for third-degree', (WidgetTester tester) async {
      final thirdDegree = albumItems.firstWhere((a) => a.title == 'third-degree');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 350,
              child: AlbumGridItem(item: thirdDegree),
            ),
          ),
        ),
      );

      expect(find.text('third-degree'), findsOneWidget);
      expect(find.text('coming march 2027'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsWidgets);
    });

    testWidgets('AlbumDetailPage displays locked details for third-degree once without duplicate or lyrics', (WidgetTester tester) async {
      final thirdDegree = albumItems.firstWhere((a) => a.title == 'third-degree');

      // Test on desktop screen size (>800 wide)
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: AlbumDetailPage(item: thirdDegree),
        ),
      );

      expect(find.text('third-degree'), findsOneWidget);
      expect(find.text('your order is in the oven.'), findsOneWidget);
      expect(find.text('STATUS: ENCRYPTED // LOCKED'), findsNothing);
      expect(find.text('estimated delivery time: march 2027'), findsOneWidget);
      expect(find.text('emergency_overheat.sh'), findsNothing);
      expect(find.byTooltip('launch_protocol: overheat'), findsOneWidget);
      // Ensure lyrics button is hidden
      expect(find.textContaining('lyrics.expand'), findsNothing);
    });
  });

  group('Home Page Fire Icon', () {
    testWidgets('Fire icon exists at bottom of HomePage', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HomePage(),
          ),
        ),
      );

      // Verify the fire icon is present via SocialIcon with fire icon & tooltip
      final fireSocialIconFinder = find.byWidgetPredicate(
        (widget) => widget is SocialIcon && widget.icon == FontAwesomeIcons.fire,
      );
      expect(fireSocialIconFinder, findsOneWidget);
      expect(find.byTooltip('overheat'), findsOneWidget);
    });
  });

  group('OverheatPage flow', () {
    testWidgets('OverheatPage runs overheating sequence without loading bar, shows white text, and fireplace', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OverheatPage(),
        ),
      );

      // Initial state is overheating - verify loading bar is removed
      expect(find.text('SYSTEM OVERHEATING'), findsOneWidget);
      expect(find.textContaining('█'), findsNothing);

      // Advance timer past overheating phase (3500ms)
      await tester.pump(const Duration(milliseconds: 3600));

      // Announcement text should now appear and be styled with white color
      final textFinder = find.textContaining('third-degree coming march 2027');
      expect(textFinder, findsOneWidget);
      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.style?.color, Colors.white);

      // Advance past announcement display (2800ms) + fade duration (1000ms)
      await tester.pump(const Duration(milliseconds: 4000));

      // Fireplace should now be showing indefinitely with exit prompt
      expect(find.text('[ click anywhere to exit ]'), findsOneWidget);

      // Tapping anywhere exits
      await tester.tap(find.byType(OverheatPage));
      await tester.pump();
    });

    testWidgets('OverheatPage does not overflow on mobile screens', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: OverheatPage(),
        ),
      );

      // Verify no overflow during overheating on mobile
      expect(find.text('SYSTEM OVERHEATING'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Advance to announcement
      await tester.pump(const Duration(milliseconds: 3600));
      expect(find.textContaining('third-degree coming march 2027'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
