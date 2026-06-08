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
}
