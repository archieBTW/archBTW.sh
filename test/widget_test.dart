import 'package:flutter_test/flutter_test.dart';
import 'package:archbtw_sh/main.dart';

void main() {
  testWidgets('ArchWebsite smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ArchWebsite());
    await tester.pump(const Duration(seconds: 5));
  });
}
