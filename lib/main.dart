import 'dart:async';

import 'package:flutter/material.dart';

import 'data/favorite_recipes_store.dart';
import 'data/fridge_store.dart';
import 'data/profile_store.dart';
import 'data/recipe_notes_store.dart';
import 'data/scan_history_store.dart';
import 'data/shopping_list_store.dart';
import 'screens/fridge_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/recipes_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/shopping_list_screen.dart';
import 'services/auth_service.dart';
import 'services/cloud_favorite_recipes_service.dart';
import 'services/cloud_foods_service.dart';
import 'services/cloud_recipe_notes_service.dart';
import 'services/cloud_scan_history_service.dart';
import 'services/cloud_shopping_list_service.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService.initializeIfConfigured();

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
    required this.scanHistoryStore,
    required this.favoriteRecipesStore,
    required this.recipeNotesStore,
    required this.authService,
  });

  final FridgeStore fridgeStore;
  final ProfileStore profileStore;
  final ShoppingListStore shoppingListStore;
  final ScanHistoryStore scanHistoryStore;
  final FavoriteRecipesStore favoriteRecipesStore;
  final RecipeNotesStore recipeNotesStore;
  final AuthService authService;

  static Future<_AppStores> load() async {
    final results = await Future.wait([
      FridgeStore.load(),
      ProfileStore.load(),
      ShoppingListStore.load(),
      ScanHistoryStore.load(),
      FavoriteRecipesStore.load(),
      RecipeNotesStore.load(),
    ]);

    final authService = AuthService();

    return _AppStores(
      fridgeStore: results[0] as FridgeStore,
      profileStore: results[1] as ProfileStore,
      shoppingListStore: results[2] as ShoppingListStore,
      scanHistoryStore: results[3] as ScanHistoryStore,
      favoriteRecipesStore: results[4] as FavoriteRecipesStore,
      recipeNotesStore: results[5] as RecipeNotesStore,
      authService: authService,
    );
  }

  void dispose() {
    fridgeStore.dispose();
    profileStore.dispose();
    shoppingListStore.dispose();
    scanHistoryStore.dispose();
    favoriteRecipesStore.dispose();
    recipeNotesStore.dispose();
    authService.dispose();
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
  static const _cloudSyncDelay = Duration(milliseconds: 1200);

  int _selectedIndex = 0;
  Timer? _fridgeCloudSyncDebounce;
  Timer? _shoppingListCloudSyncDebounce;
  Timer? _scanHistoryCloudSyncDebounce;
  Timer? _favoriteRecipesCloudSyncDebounce;
  Timer? _recipeNotesCloudSyncDebounce;
  bool _isUploadingFridgeToCloud = false;
  bool _isUploadingShoppingListToCloud = false;
  bool _isUploadingScanHistoryToCloud = false;
  bool _isUploadingFavoriteRecipesToCloud = false;
  bool _isUploadingRecipeNotesToCloud = false;
  bool _isRestoringCloudData = false;

  @override
  void initState() {
    super.initState();
    widget.stores.fridgeStore.addListener(_scheduleFridgeCloudSync);
    widget.stores.shoppingListStore.addListener(_scheduleShoppingListCloudSync);
    widget.stores.scanHistoryStore.addListener(_scheduleScanHistoryCloudSync);
    widget.stores.favoriteRecipesStore.addListener(
      _scheduleFavoriteRecipesCloudSync,
    );
    widget.stores.recipeNotesStore.addListener(_scheduleRecipeNotesCloudSync);
  }

  @override
  void dispose() {
    _fridgeCloudSyncDebounce?.cancel();
    _shoppingListCloudSyncDebounce?.cancel();
    _scanHistoryCloudSyncDebounce?.cancel();
    _favoriteRecipesCloudSyncDebounce?.cancel();
    _recipeNotesCloudSyncDebounce?.cancel();
    widget.stores.fridgeStore.removeListener(_scheduleFridgeCloudSync);
    widget.stores.shoppingListStore.removeListener(
      _scheduleShoppingListCloudSync,
    );
    widget.stores.scanHistoryStore.removeListener(
      _scheduleScanHistoryCloudSync,
    );
    widget.stores.favoriteRecipesStore.removeListener(
      _scheduleFavoriteRecipesCloudSync,
    );
    widget.stores.recipeNotesStore.removeListener(
      _scheduleRecipeNotesCloudSync,
    );
    widget.stores.dispose();
    super.dispose();
  }

  void _scheduleFridgeCloudSync() {
    if (_isRestoringCloudData || !widget.stores.authService.isSignedIn) return;

    _fridgeCloudSyncDebounce?.cancel();
    _fridgeCloudSyncDebounce = Timer(
      _cloudSyncDelay,
      _uploadFridgeToCloudSilently,
    );
  }

  Future<void> _uploadFridgeToCloudSilently() async {
    if (_isRestoringCloudData ||
        _isUploadingFridgeToCloud ||
        !widget.stores.authService.isSignedIn) {
      return;
    }

    _isUploadingFridgeToCloud = true;
    try {
      await CloudFoodsService.uploadFoods(widget.stores.fridgeStore.foods);
      debugPrint('Frigo synchronisé automatiquement avec Supabase.');
    } catch (error) {
      debugPrint('Synchronisation automatique du frigo impossible : $error');
    } finally {
      _isUploadingFridgeToCloud = false;
    }
  }

  void _scheduleShoppingListCloudSync() {
    if (_isRestoringCloudData ||
        !SupabaseService.isInitialized ||
        !widget.stores.authService.isSignedIn) {
      return;
    }

    _shoppingListCloudSyncDebounce?.cancel();
    _shoppingListCloudSyncDebounce = Timer(
      _cloudSyncDelay,
      _uploadShoppingListToCloudSilently,
    );
  }

  Future<void> _uploadShoppingListToCloudSilently() async {
    if (_isRestoringCloudData ||
        _isUploadingShoppingListToCloud ||
        !SupabaseService.isInitialized ||
        !widget.stores.authService.isSignedIn) {
      return;
    }

    _isUploadingShoppingListToCloud = true;
    try {
      await CloudShoppingListService.uploadItems(
        widget.stores.shoppingListStore.items,
      );
      debugPrint(
        'Liste de courses synchronisée automatiquement avec Supabase.',
      );
    } catch (error) {
      debugPrint(
        'Synchronisation automatique de la liste de courses impossible : '
        '$error',
      );
    } finally {
      _isUploadingShoppingListToCloud = false;
    }
  }

  void _scheduleScanHistoryCloudSync() {
    if (_isRestoringCloudData ||
        !SupabaseService.isInitialized ||
        !widget.stores.authService.isSignedIn) {
      return;
    }

    _scanHistoryCloudSyncDebounce?.cancel();
    _scanHistoryCloudSyncDebounce = Timer(
      _cloudSyncDelay,
      _uploadScanHistoryToCloudSilently,
    );
  }

  Future<void> _uploadScanHistoryToCloudSilently() async {
    if (_isRestoringCloudData ||
        _isUploadingScanHistoryToCloud ||
        !SupabaseService.isInitialized ||
        !widget.stores.authService.isSignedIn) {
      return;
    }

    _isUploadingScanHistoryToCloud = true;
    try {
      await CloudScanHistoryService.uploadItems(
        widget.stores.scanHistoryStore.items,
      );
      debugPrint(
        'Historique des scans synchronisé automatiquement avec Supabase.',
      );
    } catch (error) {
      debugPrint(
        'Synchronisation automatique de l’historique des scans impossible : '
        '$error',
      );
    } finally {
      _isUploadingScanHistoryToCloud = false;
    }
  }

  void _scheduleFavoriteRecipesCloudSync() {
    if (_isRestoringCloudData ||
        !SupabaseService.isInitialized ||
        !widget.stores.authService.isSignedIn) {
      return;
    }

    _favoriteRecipesCloudSyncDebounce?.cancel();
    _favoriteRecipesCloudSyncDebounce = Timer(
      _cloudSyncDelay,
      _uploadFavoriteRecipesToCloudSilently,
    );
  }

  Future<void> _uploadFavoriteRecipesToCloudSilently() async {
    if (_isRestoringCloudData ||
        _isUploadingFavoriteRecipesToCloud ||
        !SupabaseService.isInitialized ||
        !widget.stores.authService.isSignedIn) {
      return;
    }

    _isUploadingFavoriteRecipesToCloud = true;
    try {
      await CloudFavoriteRecipesService.uploadFavorites(
        widget.stores.favoriteRecipesStore.favoriteNames,
      );
      debugPrint(
        'Recettes favorites synchronisées automatiquement avec Supabase.',
      );
    } catch (error) {
      debugPrint(
        'Synchronisation automatique des recettes favorites impossible : '
        '$error',
      );
    } finally {
      _isUploadingFavoriteRecipesToCloud = false;
    }
  }

  void _scheduleRecipeNotesCloudSync() {
    if (_isRestoringCloudData ||
        !SupabaseService.isInitialized ||
        !widget.stores.authService.isSignedIn) {
      return;
    }

    _recipeNotesCloudSyncDebounce?.cancel();
    _recipeNotesCloudSyncDebounce = Timer(
      _cloudSyncDelay,
      _uploadRecipeNotesToCloudSilently,
    );
  }

  Future<void> _uploadRecipeNotesToCloudSilently() async {
    if (_isRestoringCloudData ||
        _isUploadingRecipeNotesToCloud ||
        !SupabaseService.isInitialized ||
        !widget.stores.authService.isSignedIn) {
      return;
    }

    _isUploadingRecipeNotesToCloud = true;
    try {
      await CloudRecipeNotesService.uploadNotes(
        widget.stores.recipeNotesStore.notesByRecipeName,
      );
      debugPrint(
        'Notes de recettes synchronisées automatiquement avec Supabase.',
      );
    } catch (error) {
      debugPrint(
        'Synchronisation automatique des notes de recettes impossible : '
        '$error',
      );
    } finally {
      _isUploadingRecipeNotesToCloud = false;
    }
  }

  Future<void> _setCloudRestoreInProgress(bool isRestoring) async {
    _isRestoringCloudData = isRestoring;

    if (!isRestoring) return;

    _fridgeCloudSyncDebounce?.cancel();
    _shoppingListCloudSyncDebounce?.cancel();
    _scanHistoryCloudSyncDebounce?.cancel();
    _favoriteRecipesCloudSyncDebounce?.cancel();
    _recipeNotesCloudSyncDebounce?.cancel();

    while (_isUploadingFridgeToCloud ||
        _isUploadingShoppingListToCloud ||
        _isUploadingScanHistoryToCloud ||
        _isUploadingFavoriteRecipesToCloud ||
        _isUploadingRecipeNotesToCloud) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  void _goToFridge() {
    setState(() => _selectedIndex = _fridgeTabIndex);
  }

  void _goToTab(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _resetDemoData() async {
    widget.stores.fridgeStore.resetDemoData();
    widget.stores.shoppingListStore.clearAll();
    widget.stores.scanHistoryStore.clearAll();
    setState(() => _selectedIndex = 0);
  }

  @override
  Widget build(BuildContext context) {
    final fridgeStore = widget.stores.fridgeStore;
    final profileStore = widget.stores.profileStore;
    final shoppingListStore = widget.stores.shoppingListStore;
    final scanHistoryStore = widget.stores.scanHistoryStore;
    final favoriteRecipesStore = widget.stores.favoriteRecipesStore;
    final recipeNotesStore = widget.stores.recipeNotesStore;
    final authService = widget.stores.authService;

    final screens = [
      HomeScreen(
        store: fridgeStore,
        shoppingListStore: shoppingListStore,
        scanHistoryStore: scanHistoryStore,
        onNavigateToTab: _goToTab,
      ),
      FridgeScreen(
        store: fridgeStore,
        shoppingStore: shoppingListStore,
      ),
      ScanScreen(
        store: fridgeStore,
        historyStore: scanHistoryStore,
        onNavigateToFridge: _goToFridge,
      ),
      RecipesScreen(
        store: fridgeStore,
        profileStore: profileStore,
        shoppingListStore: shoppingListStore,
        favoriteRecipesStore: favoriteRecipesStore,
        recipeNotesStore: recipeNotesStore,
      ),
      ShoppingListScreen(
        shoppingStore: shoppingListStore,
        fridgeStore: fridgeStore,
      ),
      ProfileScreen(
        store: profileStore,
        fridgeStore: fridgeStore,
        shoppingListStore: shoppingListStore,
        scanHistoryStore: scanHistoryStore,
        favoriteRecipesStore: favoriteRecipesStore,
        recipeNotesStore: recipeNotesStore,
        authService: authService,
        onCloudRestoreStateChanged: _setCloudRestoreInProgress,
        onResetDemoData: _resetDemoData,
      ),
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
