import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodie/app/app.dart';
import 'package:foodie/pages/splash_page.dart';
import 'package:foodie/providers/storage_provider.dart';

import 'test_helper.dart';

void main() {
  testWidgets('App renders SplashPage at initial route', (
    WidgetTester tester,
  ) async {
    // mock storage initialized
    final boxes = await initTestBoxes();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [foodieBoxesProvider.overrideWithValue(boxes)],
        child: const FoodieApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(SplashPage), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('FOODIE.ID'),
      ),
      findsOneWidget,
    );
    expect(find.text('Mulai Eksplorasi →'), findsOneWidget);
  });
}
