import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:alhudhud/providers/app_state_provider.dart';
import 'package:alhudhud/features/customer/ride_map_selection_screen.dart';
import 'package:alhudhud/features/customer/trip_details_screen.dart';

Widget _wrap(Widget child) {
  return MultiProvider(
    providers: [ChangeNotifierProvider(create: (_) => AppStateProvider())],
    child: MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar', '')],
      locale: const Locale('ar', ''),
      home: child,
    ),
  );
}

void main() {
  testWidgets('pickup -> destination -> trip details flow', (tester) async {
    await tester.pumpWidget(_wrap(const RideMapSelectionScreen()));

    // Let the district GeoJSON asset load.
    await tester.pumpAndSettle();

    // Pickup already defaults to "موقعي الحالي"; destination is empty.
    expect(find.text('موقعي الحالي'), findsWidgets);
    expect(find.text('متابعة'), findsNothing);

    // Search for a district by name and pick it.
    await tester.enterText(find.byType(TextFormField).first, 'تفرغ زينة');
    await tester.pumpAndSettle();

    expect(find.text('مقاطعة'), findsOneWidget); // district suggestion row
    await tester.tap(find.text('تفرغ زينة').first);
    await tester.pumpAndSettle();

    // The district places bottom sheet should now list its POIs
    // (the sheet opens with the destination target active by default).
    expect(find.textContaining('اختر الوجهة'), findsOneWidget);
    expect(find.text('حي النخيل'), findsOneWidget);
    await tester.tap(find.text('حي النخيل'));
    await tester.pumpAndSettle();

    // Destination is now set, so the continue button should appear.
    expect(find.text('متابعة'), findsOneWidget);
    expect(find.text('حي النخيل'), findsOneWidget);

    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();

    // We should have landed on the trip details / confirmation screen.
    expect(find.byType(TripDetailsScreen), findsOneWidget);
    expect(find.text('تفاصيل وتأكيد المشوار'), findsOneWidget);
    expect(find.textContaining('تأكيد طلب المشوار'), findsOneWidget);
  });
}
