import 'package:archbtw_sh/global/colors.dart';
import 'package:archbtw_sh/pages/home/home_page.dart';
import 'package:archbtw_sh/widgets/header.dart';
import 'package:archbtw_sh/widgets/social_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

void main() {
  group('Angel Tree / Adopt a Family Icon', () {
    testWidgets('HomePage displays Angel Tree icon in bottom social icon row', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomePage())),
      );

      final angelTreeIconFinder = find.byKey(const Key('angel_tree_button'));
      expect(angelTreeIconFinder, findsOneWidget);

      final SocialIcon iconWidget = tester.widget<SocialIcon>(
        angelTreeIconFinder,
      );
      expect(iconWidget.icon, equals(FontAwesomeIcons.tree));
      expect(iconWidget.url, equals('https://saangeltree.org'));
      expect(iconWidget.tooltip, contains('angel tree'));
      expect(iconWidget.hoverColor, equals(kHolidayGreen));
    });

    testWidgets(
      'HomePage does not overflow on small 320px width mobile screens with 6 icons',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: HomePage())),
        );

        await tester.pump(const Duration(milliseconds: 1500));
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Holiday String Lights Interaction & Modes', () {
    testWidgets('HolidayStringLights defaults to solid mode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HolidayStringLights())),
      );

      final state = tester.state<HolidayStringLightsState>(
        find.byType(HolidayStringLights),
      );
      expect(state.currentMode, equals(HolidayLightsMode.solid));
      expect(
        find.byTooltip('Holiday lights: solid (tap to change)'),
        findsOneWidget,
      );
    });

    testWidgets(
      'Tapping HolidayStringLights cycles modes: solid -> twinkle -> chase -> pulse -> off -> solid',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: HolidayStringLights())),
        );

        final lightsFinder = find.byKey(const Key('holiday_string_lights'));
        expect(lightsFinder, findsOneWidget);

        final state = tester.state<HolidayStringLightsState>(
          find.byType(HolidayStringLights),
        );

        // Initial state: solid
        expect(state.currentMode, equals(HolidayLightsMode.solid));

        // 1st tap: solid -> twinkle
        await tester.tap(lightsFinder);
        await tester.pump();
        expect(state.currentMode, equals(HolidayLightsMode.twinkle));
        expect(
          find.byTooltip('Holiday lights: twinkle (tap to change)'),
          findsOneWidget,
        );

        // 2nd tap: twinkle -> chase
        await tester.tap(lightsFinder);
        await tester.pump();
        expect(state.currentMode, equals(HolidayLightsMode.chase));
        expect(
          find.byTooltip('Holiday lights: chase (tap to change)'),
          findsOneWidget,
        );

        // 3rd tap: chase -> pulse
        await tester.tap(lightsFinder);
        await tester.pump();
        expect(state.currentMode, equals(HolidayLightsMode.pulse));
        expect(
          find.byTooltip('Holiday lights: pulse (tap to change)'),
          findsOneWidget,
        );

        // 4th tap: pulse -> off
        await tester.tap(lightsFinder);
        await tester.pump();
        expect(state.currentMode, equals(HolidayLightsMode.off));
        expect(
          find.byTooltip('Holiday lights: off (tap to change)'),
          findsOneWidget,
        );

        // 5th tap: off -> solid
        await tester.tap(lightsFinder);
        await tester.pump();
        expect(state.currentMode, equals(HolidayLightsMode.solid));
        expect(
          find.byTooltip('Holiday lights: solid (tap to change)'),
          findsOneWidget,
        );
      },
    );
  });
}
