import 'package:flutter/material.dart';

import 'data/fridge_store.dart';
import 'data/profile_store.dart';
import 'data/shopping_list_store.dart';
import 'screens/fridge_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/recipes_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/shopping_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Fridge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6F4DBF)),
      ),
      home: FutureBuilder<_AppStores>(
        future: _AppStores.load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _LoadingScreen();
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const _LoadingScreen(
              message: 'Impossible de charger les données',
            );
          }

          return MainNavigation(stores: snapshot.data!);
        },
      ),
    );
  }
}

class _AppStores {
  const _AppStores({
    required this.fridgeStore,
    required this.profileStore,
    required this.shoppingListStore,
  });

  final FridgeStore fridgeStore;
  final ProfileStore profileStore;
  final ShoppingListStore shoppingListStore;

  static Future<_AppStores> load() async {
    final results = await Future.wait([
      FridgeStore.load(),
      ProfileStore.load(),
      ShoppingListStore.load(),
    ]);

    return _AppStores(
      fridgeStore: results[0] as FridgeStore,
      profileStore: results[1] as ProfileStore,
      shoppingListStore: results[2] as ShoppingListStore,
    );
  }

  void dispose() {
    fridgeStore.dispose();
    profileStore.dispose();
    shoppingListStore.dispose();
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(message!),
            ],
          ],
        ),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key, required this.stores});

  final _AppStores stores;

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  static const _fridgeTabIndex = 1;

  int _selectedIndex = 0;

  @override
  void dispose() {
    widget.stores.dispose();
    super.dispose();
  }

  void _goToFridge() {
    setState(() => _selectedIndex = _fridgeTabIndex);
  }

  void _goToTab(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final fridgeStore = widget.stores.fridgeStore;
    final profileStore = widget.stores.profileStore;
    final shoppingListStore = widget.stores.shoppingListStore;

    final screens = [
      HomeScreen(
        store: fridgeStore,
        onNavigateToTab: _goToTab,
      ),
      FridgeScreen(store: fridgeStore),
      ScanScreen(
        store: fridgeStore,
        onNavigateToFridge: _goToFridge,
      ),
      RecipesScreen(
        store: fridgeStore,
        profileStore: profileStore,
        shoppingListStore: shoppingListStore,
      ),
      ShoppingListScreen(
        shoppingStore: shoppingListStore,
        fridgeStore: fridgeStore,
      ),
      ProfileScreen(store: profileStore),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _goToTab,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.kitchen_rounded),
            label: 'Frigo',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt_rounded),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu_rounded),
            label: 'Recettes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_rounded),
            label: 'Courses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
