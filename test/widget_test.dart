import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alhudhud/main.dart';

void main() {
  testWidgets('App launches and shows the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('الهدهد'), findsOneWidget);

    // Dispose the widget tree before the splash screen's navigation timer
    // fires, so it gets cancelled cleanly and no timer is left pending.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
