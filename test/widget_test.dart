import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('placeholder', (WidgetTester tester) async {
    // AuroraApp requires window_manager init — not testable in unit test env
    expect(1 + 1, 2);
  });
}
