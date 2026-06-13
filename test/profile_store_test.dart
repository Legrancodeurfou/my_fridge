import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_fridge/data/profile_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'le profil utilise un nom neutre par défaut et refuse un nom vide',
    () async {
      SharedPreferences.setMockInitialValues({});

      final store = await ProfileStore.load();

      expect(store.profile.name, isEmpty);
      expect(await store.updateName('   '), isFalse);
      expect(store.profile.name, isEmpty);

      expect(await store.updateName('  Camille  '), isTrue);
      expect(store.profile.name, 'Camille');
    },
  );

  test('le nom Google remplace uniquement l’ancien fallback Esteban', () async {
    SharedPreferences.setMockInitialValues({'profile_name': 'Esteban'});

    final store = await ProfileStore.load();

    expect(await store.updateNameFromAuthIfNeeded('Alex Morgan'), isTrue);
    expect(store.profile.name, 'Alex Morgan');
    expect(await store.updateNameFromAuthIfNeeded('Autre nom'), isFalse);
    expect(store.profile.name, 'Alex Morgan');
  });

  test('la fermeture de l’information scan est mémorisée localement', () async {
    SharedPreferences.setMockInitialValues({});

    final store = await ProfileStore.load();
    expect(store.scanInfoSeen, isFalse);

    await store.markScanInfoSeen();
    final reloadedStore = await ProfileStore.load();

    expect(reloadedStore.scanInfoSeen, isTrue);
  });
}
