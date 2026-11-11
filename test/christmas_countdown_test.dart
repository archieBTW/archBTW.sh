import 'package:archbtw_sh/pages/home/home_page.dart';
import 'package:archbtw_sh/widgets/christmas_countdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChristmasCountdown Widget', () {
    testWidgets('renders countdown with days, hours, minutes, and seconds',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChristmasCountdown(
              currentTimeProvider: () => DateTime(2026, 11, 10, 18, 15, 40),
            ),
          ),
        ),
      );

      expect(find.textContaining('christmas countdown:'), findsOneWidget);
      expect(find.textContaining('44d'), findsOneWidget);
      expect(find.textContaining('05h'), findsOneWidget);
      expect(find.textContaining('44m'), findsOneWidget);
      expect(find.textContaining('20s'), findsOneWidget);
    });

    testWidgets('ticks every second and decrements remaining time',
        (WidgetTester tester) async {
      DateTime current = DateTime(2026, 12, 24, 23, 59, 50);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChristmasCountdown(
              currentTimeProvider: () => current,
            ),
          ),
        ),
      );

      expect(find.textContaining('10s'), findsOneWidget);

      current = current.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('09s'), findsOneWidget);
    });

    testWidgets('shows merry christmas on Christmas Day (Dec 25)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChristmasCountdown(
              currentTimeProvider: () => DateTime(2026, 12, 25, 10, 30, 0),
            ),
          ),
        ),
      );

      expect(find.textContaining('merry christmas!'), findsOneWidget);
      expect(find.textContaining('countdown'), findsNothing);
    });

    testWidgets('targets next year after Christmas (e.g. Dec 26)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChristmasCountdown(
              currentTimeProvider: () => DateTime(2026, 12, 26, 0, 0, 0),
            ),
          ),
        ),
      );

      // Dec 26, 2026 to Dec 25, 2027 is 364 days
      expect(find.textContaining('364d'), findsOneWidget);
    });
    testWidgets('ChristmasCountdown does not have a border container',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChristmasCountdown(
              currentTimeProvider: () => DateTime(2026, 11, 10, 18, 15, 40),
            ),
          ),
        ),
      );

      final containerWithBorder = find.byWidgetPredicate(
        (w) => w is Container && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).border != null,
      );
      expect(containerWithBorder, findsNothing);
    });
  });

  group('HomePage Christmas Countdown', () {
    testWidgets('HomePage includes ChristmasCountdown below the social icons',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HomePage(),
          ),
        ),
      );

      expect(find.byType(ChristmasCountdown), findsOneWidget);
      expect(find.textContaining('christmas countdown:'), findsOneWidget);

      // Verify ChristmasCountdown is positioned vertically below the social icons
      final countdownFinder = find.byType(ChristmasCountdown);
      final socialIconFinder = find.byType(Row).last;

      final countdownTop = tester.getTopLeft(countdownFinder).dy;
      final socialIconTop = tester.getTopLeft(socialIconFinder).dy;

      expect(countdownTop, greaterThan(socialIconTop));
    });

    testWidgets('HomePage does not overflow on small mobile screens',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HomePage(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 3000));
      expect(tester.takeException(), isNull);
    });
  });
}

