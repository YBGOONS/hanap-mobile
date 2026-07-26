import 'package:flutter_test/flutter_test.dart';

import 'package:hanap_mobile/main.dart';

void main() {
  testWidgets('HomeScreen renders the hero and nav', (WidgetTester tester) async {
    await tester.pumpWidget(const HanapApp());
    // Flush the (finite) entrance-fade timers from flutter_animate; avoid
    // pumpAndSettle since PulsingDot repeats its animation forever.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
