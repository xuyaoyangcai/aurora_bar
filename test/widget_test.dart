import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_bar/main.dart';

void main() {
  testWidgets('AuroraBar renders', (WidgetTester tester) async {
    await tester.pumpWidget(const AuroraBar());
    expect(find.text('Aurora'), findsOneWidget);
  });
}
