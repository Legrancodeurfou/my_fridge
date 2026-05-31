import 'package:flutter/material.dart';

import 'data/fridge_store.dart';
import 'screens/fridge_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/recipes_screen.dart';
import 'screens/scan_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  static const _fridgeTabIndex = 1;

  late final FridgeStore _fridgeStore;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _fridgeStore = FridgeStore();
  }

  @override
  void dispose() {
    _fridgeStore.dispose();
    super.dispose();
  }

  void _goToFridge() {
    setState(() => _selectedIndex = _fridgeTabIndex);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const HomeScreen(),
      FridgeScreen(store: _fridgeStore),
      ScanScreen(
        store: _fridgeStore,
        onNavigateToFridge: _goToFridge,
      ),
      const RecipesScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.kitchen),
            label: 'Frigo',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Recettes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
