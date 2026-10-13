import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/main.dart';

void main() {
  testWidgets('Sakhi welcome screen shows the brand and welcome message',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SakhiApp());
    await tester.pumpAndSettle();

    expect(find.text('Sakhi'), findsOneWidget);
    expect(find.text('Safer Women. Stronger Together.'), findsOneWidget);
    expect(
      find.text('A Safer, Brighter Tomorrow\nfor Every Woman'),
      findsOneWidget,
    );
    expect(
      find.text('Safety  •  Community  •  Wellness  •  Opportunities'),
      findsOneWidget,
    );
  });
}
