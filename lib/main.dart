import 'package:flutter/material.dart';

import 'data/fridge_store.dart';
import 'data/profile_store.dart';
import 'screens/fridge_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/recipes_screen.dart';
import 'screens/scan_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyFridgeApp());
}

class MyFridgeApp extends StatelessWidget {
  const MyFridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Fridge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6F4DBF)),
      ),
      home: FutureBuilder<AppStores>(
        future: AppStores.load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingScreen();
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const LoadingScreen(message: 'Impossible de charger l’application');
          }

          return MainNavigation(stores: snapshot.data!);
        },
      ),
    );
  }
}

class AppStores {
  const AppStores({required this.fridgeStore, required this.profileStore});

  final FridgeStore fridgeStore;
  final ProfileStore profileStore;

  static Future<AppStores> load() async {
    final results = await Future.wait([
      FridgeStore.load(),
      ProfileStore.load(),
    ]);

    return AppStores(
      fridgeStore: results[0] as FridgeStore,
      profileStore: results[1] as ProfileStore,
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key, this.message});

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

enum AppTab { home, fridge, scan, recipes, profile }

extension AppTabIndex on AppTab {
  int get index => AppTab.values.indexOf(this);
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key, required this.stores});

  final AppStores stores;

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  AppTab _selectedTab = AppTab.home;

  FridgeStore get _fridgeStore => widget.stores.fridgeStore;
  ProfileStore get _profileStore => widget.stores.profileStore;

  @override
  void dispose() {
    _fridgeStore.dispose();
    _profileStore.dispose();
    super.dispose();
  }

  void _goToTab(int index) {
    setState(() => _selectedTab = AppTab.values[index]);
  }

  void _goToFridge() {
    setState(() => _selectedTab = AppTab.fridge);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(store: _fridgeStore, onNavigateToTab: _goToTab),
      FridgeScreen(store: _fridgeStore),
      ScanScreen(store: _fridgeStore, onNavigateToFridge: _goToFridge),
      RecipesScreen(store: _fridgeStore, profileStore: _profileStore),
      ProfileScreen(store: _profileStore),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedTab.index, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab.index,
        onTap: _goToTab,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.kitchen_rounded), label: 'Frigo'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt_rounded), label: 'Scan'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu_rounded), label: 'Recettes'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profil'),
        ],
      ),
    );
  }
}
