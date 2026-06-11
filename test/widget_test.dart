import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_fridge/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('l’application démarre et affiche la navigation principale', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('Accueil'), findsWidgets);
    expect(find.text('Frigo'), findsWidgets);
    expect(find.text('Scan'), findsWidgets);
    expect(find.text('Profil'), findsWidgets);
  });

  testWidgets('un stock vide ouvre la mise en route depuis l’accueil', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'fridge_foods': '[]'});

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Commence par remplir ton stock'), findsOneWidget);

    await tester.tap(find.text('Mise en route'));
    await tester.pumpAndSettle();

    expect(find.text('Mise en route du stock'), findsOneWidget);
    expect(find.text('Frigo'), findsOneWidget);
    expect(find.text('Placard'), findsOneWidget);
    expect(find.text('Congélateur'), findsOneWidget);
    expect(find.text('Épices'), findsOneWidget);
    expect(find.text('Scanner un ticket'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Photo du frigo'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('Photo du frigo'), findsOneWidget);
  });
}
