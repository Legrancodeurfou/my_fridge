import 'dart:async';

import 'package:flutter/material.dart';

import '../data/favorite_recipes_store.dart';
import '../data/fridge_store.dart';
import '../data/profile_store.dart';
import '../data/recipe_notes_store.dart';
import '../data/scan_history_store.dart';
import '../data/shopping_list_store.dart';
import '../services/auth_service.dart';
import '../services/cloud_backup_service.dart';
import '../services/cloud_favorite_recipes_service.dart';
import '../services/cloud_foods_service.dart';
import '../services/cloud_recipe_notes_service.dart';
import '../services/cloud_scan_history_service.dart';
import '../services/cloud_shopping_list_service.dart';

enum _CloudOnboardingChoice { restoreCloud, keepLocal, later }

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.store,
    required this.fridgeStore,
    required this.shoppingListStore,
    required this.scanHistoryStore,
    required this.favoriteRecipesStore,
    required this.recipeNotesStore,
    required this.authService,
    required this.onCloudRestoreStateChanged,
    required this.onResetDemoData,
  });

  final ProfileStore store;
  final FridgeStore fridgeStore;
  final ShoppingListStore shoppingListStore;
  final ScanHistoryStore scanHistoryStore;
  final FavoriteRecipesStore favoriteRecipesStore;
  final RecipeNotesStore recipeNotesStore;
  final AuthService authService;
  final Future<void> Function(bool isRestoring) onCloudRestoreStateChanged;
  final Future<void> Function() onResetDemoData;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _nameController;
  bool _isSyncingFridge = false;
  bool _isRestoringCloudData = false;
  bool _isCloudOnboardingInProgress = false;
  bool _isLoadingBackups = false;
  bool _isCreatingBackup = false;
  String? _restoringBackupId;
  String? _loadedBackupUserId;
  String? _cloudOnboardingUserId;
  String? _backupError;
  List<CloudBackup> _cloudBackups = const [];
  int _backupLoadGeneration = 0;

  bool get _isCloudOperationInProgress =>
      _isRestoringCloudData ||
      _isCloudOnboardingInProgress ||
      _isCreatingBackup;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.store.profile.name);
    _nameController.addListener(_onNameChanged);
    widget.authService.addListener(_onAuthStateChanged);
    _onAuthStateChanged();
  }

  @override
  void dispose() {
    widget.authService.removeListener(_onAuthStateChanged);
    _nameController
      ..removeListener(_onNameChanged)
      ..dispose();
    super.dispose();
  }

  void _onNameChanged() {
    widget.store.updateName(_nameController.text);
  }

  void _onAuthStateChanged() {
    final userId = widget.authService.userId;

    if (userId == null) {
      _cloudOnboardingUserId = null;
    } else if (widget.authService.isCloudOnboardingPending &&
        _cloudOnboardingUserId != userId) {
      _cloudOnboardingUserId = userId;
      unawaited(_showCloudOnboarding(userId));
    }

    if (_loadedBackupUserId == userId) return;

    _loadedBackupUserId = userId;
    _backupLoadGeneration++;
    _isLoadingBackups = false;

    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _cloudBackups = const [];
        _backupError = null;
        _isLoadingBackups = false;
      });
      return;
    }

    _loadCloudBackups();
  }

  Future<void> _showCloudOnboarding(String userId) async {
    _isCloudOnboardingInProgress = true;
    var choiceWasMade = false;

    try {
      await widget.onCloudRestoreStateChanged(true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || widget.authService.userId != userId) return;

      final choice = await showDialog<_CloudOnboardingChoice>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Que veux-tu faire avec tes données cloud ?'),
            content: const Text(
              'Récupérer tes données cloud remplacera les données locales '
              'actuelles. Une sauvegarde de sécurité sera créée avant la '
              'restauration. Garder les données locales laissera la '
              'synchronisation automatique reprendre normalement.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  _CloudOnboardingChoice.later,
                ),
                child: const Text('Plus tard'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  _CloudOnboardingChoice.keepLocal,
                ),
                child: const Text('Garder mes données locales'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  _CloudOnboardingChoice.restoreCloud,
                ),
                child: const Text('Récupérer mes données cloud'),
              ),
            ],
          );
        },
      );

      choiceWasMade = choice != null;

      if (choice == _CloudOnboardingChoice.restoreCloud && mounted) {
        await _performGlobalCloudRestore(manageAutoSyncSuspension: false);
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar(
          'Le cloud est temporairement indisponible. Tes données locales '
          'restent accessibles. Détail : $error',
        );
      }
    } finally {
      await widget.onCloudRestoreStateChanged(false);
      if (choiceWasMade && widget.authService.userId == userId) {
        widget.authService.completeCloudOnboarding();
      }
      _isCloudOnboardingInProgress = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadCloudBackups() async {
    if (!widget.authService.isSignedIn || _isLoadingBackups) return;

    final loadGeneration = _backupLoadGeneration;

    setState(() {
      _isLoadingBackups = true;
      _backupError = null;
    });

    try {
      final backups = await CloudBackupService.listBackups();
      if (!mounted || loadGeneration != _backupLoadGeneration) return;
      setState(() => _cloudBackups = backups);
    } catch (error) {
      if (!mounted || loadGeneration != _backupLoadGeneration) return;
      setState(() => _backupError = 'Sauvegardes indisponibles : $error');
    } finally {
      if (mounted && loadGeneration == _backupLoadGeneration) {
        setState(() => _isLoadingBackups = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      await widget.authService.signInWithGoogle();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(widget.authService.errorMessage ?? 'Connexion Google impossible'),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    await widget.authService.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: const Text('Déconnecté'),
      ),
    );
  }


  Future<void> _uploadFridgeToCloud() async {
    if (!widget.authService.isSignedIn) {
      _showSnackBar(
        'Mode local actif. Connecte-toi avec Google pour sauvegarder '
        'tes données dans le cloud.',
      );
      return;
    }

    setState(() => _isSyncingFridge = true);

    try {
      await CloudFoodsService.uploadFoods(widget.fridgeStore.foods);
      if (!mounted) return;
      _showSnackBar('Frigo sauvegardé dans le cloud avec succès.');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(
        'Le frigo n’a pas pu être sauvegardé. Tes données locales sont '
        'conservées. Détail : $error',
      );
    } finally {
      if (mounted) setState(() => _isSyncingFridge = false);
    }
  }

  Future<void> _downloadFridgeFromCloud() async {
    if (!widget.authService.isSignedIn) {
      _showSnackBar(
        'Mode local actif. Connecte-toi avec Google pour récupérer '
        'ton frigo depuis le cloud.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remplacer le frigo local ?'),
          content: const Text(
            'Les aliments actuellement dans ton frigo local seront remplacés par ceux sauvegardés dans Supabase.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Importer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSyncingFridge = true);

    try {
      final cloudFoods = await CloudFoodsService.downloadFoods();
      await widget.fridgeStore.replaceAllFoods(cloudFoods);
      if (!mounted) return;
      _showSnackBar(
        'Frigo restauré : ${cloudFoods.length} aliment(s) récupéré(s) '
        'depuis le cloud.',
      );
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(
        'Impossible de récupérer le frigo. Les données locales actuelles '
        'sont conservées. Détail : $error',
      );
    } finally {
      if (mounted) setState(() => _isSyncingFridge = false);
    }
  }

  Future<void> _restoreAllCloudData() async {
    if (_isSyncingFridge || _isCloudOperationInProgress) return;

    if (!widget.authService.isSignedIn) {
      _showSnackBar(
        'Mode local actif. Connecte-toi avec Google pour récupérer '
        'tes données cloud.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Restaurer les données cloud ?'),
          content: const Text(
            'Le frigo, les courses, les scans, les favoris et les notes '
            'locales seront remplacés par les données sauvegardées dans '
            'Supabase.\n\nUne sauvegarde de sécurité de l’état cloud actuel '
            'sera créée avant la restauration.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Restaurer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await _performGlobalCloudRestore(manageAutoSyncSuspension: true);
  }

  Future<void> _performGlobalCloudRestore({
    required bool manageAutoSyncSuspension,
  }) async {
    setState(() => _isRestoringCloudData = true);

    try {
      if (manageAutoSyncSuspension) {
        await widget.onCloudRestoreStateChanged(true);
      }

      final shouldContinue = await _createSafetyBackupOrConfirm(
        'Avant restauration globale',
      );
      if (!shouldContinue) return;

      await _downloadAllCloudDataToLocal();

      if (!mounted) return;
      _showSnackBar(
        'Restauration réussie. Tes données cloud sont maintenant disponibles '
        'dans l’application.',
      );
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(
        'La restauration n’a pas pu être terminée. Tes données locales '
        'restent accessibles. Détail : $error',
      );
    } finally {
      if (manageAutoSyncSuspension) {
        await widget.onCloudRestoreStateChanged(false);
      }
      if (mounted) setState(() => _isRestoringCloudData = false);
    }
  }

  Future<bool> _createSafetyBackupOrConfirm(
    String reason, {
    String? preserveBackupId,
  }) async {
    try {
      await CloudBackupService.createBackup(
        reason,
        preserveBackupId: preserveBackupId,
      );
      await _loadCloudBackups();
      return true;
    } catch (_) {
      if (!mounted) return false;

      final shouldContinue = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Sauvegarde de sécurité impossible'),
            content: const Text(
              'La sauvegarde de sécurité n’a pas pu être créée. '
              'Continuer quand même ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annuler la restauration'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Continuer quand même'),
              ),
            ],
          );
        },
      );

      return shouldContinue == true;
    }
  }

  Future<void> _downloadAllCloudDataToLocal() async {
    final cloudFoods = await CloudFoodsService.downloadFoods();
    final cloudShoppingItems = await CloudShoppingListService.downloadItems();
    final cloudScanHistory = await CloudScanHistoryService.downloadItems();
    final cloudFavoriteRecipes =
        await CloudFavoriteRecipesService.downloadFavorites();
    final cloudRecipeNotes = await CloudRecipeNotesService.downloadNotes();

    await widget.fridgeStore.replaceAllFoods(cloudFoods);
    await widget.shoppingListStore.replaceAllItems(cloudShoppingItems);
    await widget.scanHistoryStore.replaceAllItems(cloudScanHistory);
    await widget.favoriteRecipesStore.replaceAllFavorites(cloudFavoriteRecipes);
    await widget.recipeNotesStore.replaceAllNotes(cloudRecipeNotes);
  }

  Future<void> _createCloudBackup() async {
    if (!widget.authService.isSignedIn ||
        _isSyncingFridge ||
        _isCloudOperationInProgress) {
      return;
    }

    setState(() => _isCreatingBackup = true);

    try {
      await CloudBackupService.createBackup('Sauvegarde manuelle');
      await _loadCloudBackups();

      if (!mounted) return;
      _showSnackBar(
        'Sauvegarde cloud créée avec succès. Les 3 plus récentes sont '
        'conservées.',
      );
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(
        'La sauvegarde cloud n’a pas pu être créée. Réessaie dans quelques '
        'instants. Détail : $error',
      );
    } finally {
      if (mounted) setState(() => _isCreatingBackup = false);
    }
  }

  Future<void> _restoreCloudBackup(CloudBackup backup) async {
    if (!widget.authService.isSignedIn ||
        _isSyncingFridge ||
        _isCloudOperationInProgress) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Restaurer cette sauvegarde ?'),
          content: Text(
            'La sauvegarde du ${_formatBackupDate(backup.createdAt)} '
            'remplacera les données cloud et locales actuelles.\n\nUne '
            'sauvegarde de sécurité de l’état actuel sera créée avant la '
            'restauration.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Restaurer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isRestoringCloudData = true;
      _restoringBackupId = backup.id;
    });

    try {
      await widget.onCloudRestoreStateChanged(true);

      final shouldContinue = await _createSafetyBackupOrConfirm(
        'Avant restauration sauvegarde',
        preserveBackupId: backup.id,
      );
      if (!shouldContinue) return;

      await CloudBackupService.restoreBackup(backup.id);
      await _downloadAllCloudDataToLocal();

      if (!mounted) return;
      _showSnackBar(
        'Restauration réussie. La sauvegarde sélectionnée est maintenant '
        'active sur cet appareil.',
      );
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(
        'La sauvegarde n’a pas pu être restaurée. Tes données actuelles '
        'restent accessibles. Détail : $error',
      );
    } finally {
      await widget.onCloudRestoreStateChanged(false);
      if (mounted) {
        setState(() {
          _isRestoringCloudData = false;
          _restoringBackupId = null;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(message),
      ),
    );
  }

  Future<void> _confirmResetDemoData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Réinitialiser les données ?'),
          content: const Text(
            'Le frigo reviendra aux aliments de démo. La liste de courses et l’historique des scans seront vidés. Ton profil sera conservé.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Réinitialiser'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await widget.onResetDemoData();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: const Text('Données de démo réinitialisées'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.store, widget.authService]),
      builder: (context, _) {
        final profile = widget.store.profile;
        final colorScheme = Theme.of(context).colorScheme;

        if (_nameController.text != profile.name) {
          _nameController.text = profile.name;
          _nameController.selection = TextSelection.fromPosition(
            TextPosition(offset: _nameController.text.length),
          );
        }

        return Scaffold(
          backgroundColor: colorScheme.surfaceContainerLowest,
          appBar: AppBar(
            title: const Text('Profil'),
            centerTitle: false,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: colorScheme.surfaceContainerLowest,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _HeaderCard(nameController: _nameController),
              const SizedBox(height: 16),
              const _SectionTitle(title: 'Compte'),
              const SizedBox(height: 8),
              _AuthCard(
                authService: widget.authService,
                isDisabled: _isCloudOperationInProgress,
                onSignIn: _signInWithGoogle,
                onSignOut: _signOut,
              ),
              const SizedBox(height: 24),
              const _SectionTitle(title: 'Synchronisation cloud'),
              const SizedBox(height: 8),
              _CloudStatusCard(
                authService: widget.authService,
                isRestoring: _isRestoringCloudData,
              ),
              const SizedBox(height: 12),
              _CloudSyncCard(
                authService: widget.authService,
                isSyncing: _isSyncingFridge || _isCloudOperationInProgress,
                localFoodCount: widget.fridgeStore.foods.length,
                onUpload: _uploadFridgeToCloud,
                onDownload: _downloadFridgeFromCloud,
              ),
              if (widget.authService.isSignedIn) ...[
                const SizedBox(height: 12),
                _CloudRestoreCard(
                  isBusy: _isSyncingFridge || _isCloudOperationInProgress,
                  isRestoring: _isRestoringCloudData,
                  onRestore: _restoreAllCloudData,
                ),
                const SizedBox(height: 12),
                _CloudBackupsCard(
                  backups: _cloudBackups,
                  errorMessage: _backupError,
                  isBusy:
                      _isSyncingFridge ||
                      _isCloudOperationInProgress ||
                      _isLoadingBackups,
                  isCreating: _isCreatingBackup,
                  isLoading: _isLoadingBackups,
                  restoringBackupId: _restoringBackupId,
                  onCreate: _createCloudBackup,
                  onRefresh: _loadCloudBackups,
                  onRestore: _restoreCloudBackup,
                ),
              ],
              const SizedBox(height: 24),
              const _SectionTitle(title: 'Préférences'),
              const SizedBox(height: 8),
              _DropdownCard<CookingLevel>(
                icon: Icons.restaurant_menu_rounded,
                title: 'Niveau de cuisine',
                value: profile.cookingLevel,
                items: CookingLevel.values,
                labelBuilder: (value) => value.label,
                onChanged: (value) {
                  if (value != null) widget.store.updateCookingLevel(value);
                },
              ),
              const SizedBox(height: 12),
              _DropdownCard<ProfileGoal>(
                icon: Icons.flag_rounded,
                title: 'Objectif principal',
                value: profile.goal,
                items: ProfileGoal.values,
                labelBuilder: (value) => value.label,
                onChanged: (value) {
                  if (value != null) widget.store.updateGoal(value);
                },
              ),
              const SizedBox(height: 24),
              const _SectionTitle(title: 'Équipements disponibles'),
              const SizedBox(height: 8),
              _SwitchCard(
                icon: Icons.air_rounded,
                title: 'Airfryer',
                value: profile.hasAirfryer,
                onChanged: widget.store.updateAirfryer,
              ),
              const SizedBox(height: 10),
              _SwitchCard(
                icon: Icons.local_fire_department_rounded,
                title: 'Four',
                value: profile.hasOven,
                onChanged: widget.store.updateOven,
              ),
              const SizedBox(height: 10),
              _SwitchCard(
                icon: Icons.microwave_rounded,
                title: 'Micro-ondes',
                value: profile.hasMicrowave,
                onChanged: widget.store.updateMicrowave,
              ),
              const SizedBox(height: 10),
              _SwitchCard(
                icon: Icons.blender_rounded,
                title: 'Thermomix',
                value: profile.hasThermomix,
                onChanged: widget.store.updateThermomix,
              ),
              const SizedBox(height: 24),
              const _SectionTitle(title: 'Données de test'),
              const SizedBox(height: 8),
              _ResetDataCard(
                isDisabled: _isCloudOperationInProgress,
                onReset: _confirmResetDemoData,
              ),
              const SizedBox(height: 24),
              const _InfoCard(
                icon: Icons.info_outline_rounded,
                title: 'Version MVP',
                subtitle: 'My Fridge MVP v0.1',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.nameController});

  final TextEditingController nameController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.65),
            child: Icon(Icons.person_rounded, size: 52, color: colorScheme.primary),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: nameController,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              hintText: 'Ton prénom',
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _DropdownCard<T> extends StatelessWidget {
  const _DropdownCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final T value;
  final List<T> items;
  final String Function(T value) labelBuilder;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _CardContainer(
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              borderRadius: BorderRadius.circular(14),
              items: items
                  .map(
                    (item) => DropdownMenuItem<T>(
                      value: item,
                      child: Text(labelBuilder(item)),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _CardContainer(
      child: Material(
        color: Colors.transparent,
        child: SwitchListTile(
          value: value,
          onChanged: onChanged,
          contentPadding: EdgeInsets.zero,
          secondary: Icon(icon, color: colorScheme.primary),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}


class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.authService,
    required this.isDisabled,
    required this.onSignIn,
    required this.onSignOut,
  });

  final AuthService authService;
  final bool isDisabled;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (!authService.isAvailable) {
      return _CardContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_off_rounded, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cloud non configuré',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Supabase n’est pas encore disponible sur cette version de l’app.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (authService.isSignedIn) {
      return _CardContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user_rounded, color: colorScheme.primary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connecté',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          authService.email ?? 'Compte Supabase connecté',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: authService.isBusy || isDisabled ? null : onSignOut,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Se déconnecter'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _CardContainer(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.cloud_done_rounded, color: colorScheme.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sauvegarde cloud',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Connecte-toi pour préparer la sauvegarde de ton frigo sur Supabase.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (authService.errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                authService.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: authService.isBusy || isDisabled ? null : onSignIn,
                icon: authService.isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login_rounded),
                label: const Text('Se connecter avec Google'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloudStatusCard extends StatelessWidget {
  const _CloudStatusCard({
    required this.authService,
    required this.isRestoring,
  });

  final AuthService authService;
  final bool isRestoring;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCloudActive = authService.isAvailable && authService.isSignedIn;
    final isSyncSuspended =
        isRestoring || authService.isCloudOnboardingPending;

    final statusMessage = !isCloudActive
        ? 'Mode local uniquement'
        : isRestoring
        ? 'Synchronisation suspendue pendant la restauration'
        : authService.isCloudOnboardingPending
        ? 'Synchronisation suspendue en attente de ton choix'
        : 'Synchronisation automatique active';

    return _CardContainer(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isCloudActive
                  ? Icons.cloud_done_rounded
                  : Icons.cloud_off_rounded,
              color: isCloudActive
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'État du cloud',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    authService.isSignedIn
                        ? 'Connecté avec ${authService.email ?? 'ton compte Google'}'
                        : 'Mode local · non connecté',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isSyncSuspended
                          ? colorScheme.tertiary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: isSyncSuspended
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isCloudActive
                        ? 'Tes données sont sauvegardées automatiquement '
                              'lorsque tu es connecté.'
                        : 'Tes données restent enregistrées sur cet appareil. '
                              'Connecte-toi pour activer la sauvegarde cloud.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (isRestoring) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Restauration en cours...',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloudSyncCard extends StatelessWidget {
  const _CloudSyncCard({
    required this.authService,
    required this.isSyncing,
    required this.localFoodCount,
    required this.onUpload,
    required this.onDownload,
  });

  final AuthService authService;
  final bool isSyncing;
  final int localFoodCount;
  final VoidCallback onUpload;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canSync = authService.isAvailable && authService.isSignedIn && !isSyncing;

    return _CardContainer(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.sync_rounded, color: colorScheme.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Frigo cloud',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        authService.isSignedIn
                            ? '$localFoodCount aliment(s) dans ton frigo local. Sauvegarde ou récupère manuellement depuis Supabase.'
                            : 'Connecte-toi avec Google pour synchroniser ton frigo.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canSync ? onUpload : null,
                icon: isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_rounded),
                label: const Text('Sauvegarder mon frigo dans le cloud'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: canSync ? onDownload : null,
                icon: const Icon(Icons.cloud_download_rounded),
                label: const Text('Récupérer mon frigo depuis le cloud'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _CloudRestoreCard extends StatelessWidget {
  const _CloudRestoreCard({
    required this.isBusy,
    required this.isRestoring,
    required this.onRestore,
  });

  final bool isBusy;
  final bool isRestoring;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _CardContainer(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.cloud_download_rounded, color: colorScheme.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Restaurer mes données cloud',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Récupère le frigo, les courses, les scans, les favoris '
                        'et les notes sauvegardés. Une sauvegarde de sécurité '
                        'est créée avant toute restauration.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isBusy ? null : onRestore,
                icon: isRestoring
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.restore_rounded),
                label: Text(
                  isRestoring
                      ? 'Restauration en cours...'
                      : 'Récupérer mes données cloud',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloudBackupsCard extends StatelessWidget {
  const _CloudBackupsCard({
    required this.backups,
    required this.errorMessage,
    required this.isBusy,
    required this.isCreating,
    required this.isLoading,
    required this.restoringBackupId,
    required this.onCreate,
    required this.onRefresh,
    required this.onRestore,
  });

  final List<CloudBackup> backups;
  final String? errorMessage;
  final bool isBusy;
  final bool isCreating;
  final bool isLoading;
  final String? restoringBackupId;
  final VoidCallback onCreate;
  final VoidCallback onRefresh;
  final ValueChanged<CloudBackup> onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _CardContainer(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.backup_rounded, color: colorScheme.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sauvegardes cloud',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Seules les 3 dernières sauvegardes complètes sont '
                        'conservées. Les plus anciennes sont supprimées '
                        'automatiquement.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: isBusy ? null : onRefresh,
                  tooltip: 'Actualiser',
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (isLoading)
              Text(
                'Actualisation des sauvegardes...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else if (backups.isEmpty)
              Text(
                'Aucune sauvegarde cloud pour l’instant',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              Text(
                'Dernière sauvegarde disponible',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatBackupDate(backups.first.createdAt),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (backups.first.reason.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  backups.first.reason,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isBusy ? null : onCreate,
                icon: isCreating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_to_photos_rounded),
                label: Text(
                  isCreating
                      ? 'Création en cours...'
                      : 'Créer une sauvegarde maintenant',
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (errorMessage != null) ...[
              Text(
                errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: isBusy ? null : onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Actualiser'),
              ),
            ] else if (backups.isNotEmpty)
              for (var index = 0; index < backups.length; index++) ...[
                if (index > 0) const Divider(height: 20),
                _CloudBackupTile(
                  backup: backups[index],
                  isBusy: isBusy,
                  isRestoring: restoringBackupId == backups[index].id,
                  onRestore: () => onRestore(backups[index]),
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _CloudBackupTile extends StatelessWidget {
  const _CloudBackupTile({
    required this.backup,
    required this.isBusy,
    required this.isRestoring,
    required this.onRestore,
  });

  final CloudBackup backup;
  final bool isBusy;
  final bool isRestoring;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history_rounded, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatBackupDate(backup.createdAt),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    backup.reason,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isBusy ? null : onRestore,
            icon: isRestoring
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.restore_rounded),
            label: Text(
              isRestoring
                  ? 'Restauration en cours...'
                  : 'Restaurer une sauvegarde',
            ),
          ),
        ),
      ],
    );
  }
}

class _ResetDataCard extends StatelessWidget {
  const _ResetDataCard({
    required this.isDisabled,
    required this.onReset,
  });

  final bool isDisabled;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _CardContainer(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.restart_alt_rounded, color: colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Réinitialiser l’app',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Remet le frigo de démo, vide les courses et l’historique. Le profil est conservé.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isDisabled ? null : onReset,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réinitialiser les données de démo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _CardContainer(
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: colorScheme.primary),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(subtitle),
        ),
      ),
    );
  }
}

class _CardContainer extends StatelessWidget {
  const _CardContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

String _formatBackupDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} à $hour:$minute';
}
