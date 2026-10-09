import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/constants/app_strings.dart';
import 'package:nexora/main.dart';

void main() {
  testWidgets('NexoraApp splash screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NexoraApp());

    // Verify brand name & tagline exist
    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.tagline), findsOneWidget);
  });
}
