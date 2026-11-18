import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodie/main.dart';

void main() {
  testWidgets('App displays Foodie.id title', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FoodieApp()));
    expect(find.text('Foodie.id'), findsOneWidget);
  });
}
