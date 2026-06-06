import 'package:flutter/material.dart';

import '../data/favorite_recipes_store.dart';
import '../data/fridge_store.dart';
import '../data/profile_store.dart';
import '../data/recipe_notes_store.dart';
import '../data/scan_history_store.dart';
import '../data/shopping_list_store.dart';
import '../services/auth_service.dart';
import '../services/cloud_favorite_recipes_service.dart';
import '../services/cloud_foods_service.dart';
import '../services/cloud_recipe_notes_service.dart';
import '../services/cloud_scan_history_service.dart';
import '../services/cloud_shopping_list_service.dart';

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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.store.profile.name);
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_onNameChanged)
      ..dispose();
    super.dispose();
  }

  void _onNameChanged() {
    widget.store.updateName(_nameController.text);
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
      _showSnackBar('Connecte-toi avec Google avant de synchroniser.');
      return;
    }

    setState(() => _isSyncingFridge = true);

    try {
      await CloudFoodsService.uploadFoods(widget.fridgeStore.foods);
      if (!mounted) return;
      _showSnackBar('Frigo sauvegardé dans le cloud.');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Sauvegarde cloud impossible : $error');
    } finally {
      if (mounted) setState(() => _isSyncingFridge = false);
    }
  }

  Future<void> _downloadFridgeFromCloud() async {
    if (!widget.authService.isSignedIn) {
      _showSnackBar('Connecte-toi avec Google avant de synchroniser.');
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
      _showSnackBar('${cloudFoods.length} aliment(s) récupéré(s) depuis le cloud.');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Import cloud impossible : $error');
    } finally {
      if (mounted) setState(() => _isSyncingFridge = false);
    }
  }

  Future<void> _restoreAllCloudData() async {
    if (_isSyncingFridge || _isRestoringCloudData) return;

    if (!widget.authService.isSignedIn) {
      _showSnackBar('Connecte-toi avec Google avant de restaurer tes données.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Restaurer les données cloud ?'),
          content: const Text(
            'Les données locales actuelles seront remplacées par les données sauvegardées dans Supabase.',
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

    setState(() => _isRestoringCloudData = true);

    try {
      await widget.onCloudRestoreStateChanged(true);

      final cloudFoods = await CloudFoodsService.downloadFoods();
      final cloudShoppingItems = await CloudShoppingListService.downloadItems();
      final cloudScanHistory = await CloudScanHistoryService.downloadItems();
      final cloudFavoriteRecipes =
          await CloudFavoriteRecipesService.downloadFavorites();
      final cloudRecipeNotes = await CloudRecipeNotesService.downloadNotes();

      await widget.fridgeStore.replaceAllFoods(cloudFoods);
      await widget.shoppingListStore.replaceAllItems(cloudShoppingItems);
      await widget.scanHistoryStore.replaceAllItems(cloudScanHistory);
      await widget.favoriteRecipesStore.replaceAllFavorites(
        cloudFavoriteRecipes,
      );
      await widget.recipeNotesStore.replaceAllNotes(cloudRecipeNotes);

      if (!mounted) return;
      _showSnackBar('Tes données cloud ont été restaurées.');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Restauration cloud impossible : $error');
    } finally {
      await widget.onCloudRestoreStateChanged(false);
      if (mounted) setState(() => _isRestoringCloudData = false);
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
                isDisabled: _isRestoringCloudData,
                onSignIn: _signInWithGoogle,
                onSignOut: _signOut,
              ),
              const SizedBox(height: 24),
              const _SectionTitle(title: 'Synchronisation cloud'),
              const SizedBox(height: 8),
              _CloudSyncCard(
                authService: widget.authService,
                isSyncing: _isSyncingFridge || _isRestoringCloudData,
                localFoodCount: widget.fridgeStore.foods.length,
                onUpload: _uploadFridgeToCloud,
                onDownload: _downloadFridgeFromCloud,
              ),
              if (widget.authService.isSignedIn) ...[
                const SizedBox(height: 12),
                _CloudRestoreCard(
                  isBusy: _isSyncingFridge || _isRestoringCloudData,
                  isRestoring: _isRestoringCloudData,
                  onRestore: _restoreAllCloudData,
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
                isDisabled: _isRestoringCloudData,
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
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
        secondary: Icon(icon, color: colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
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
                        'Remplace le frigo, les courses, les scans, les favoris et les notes locales par les données sauvegardées dans Supabase.',
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
                      : 'Récupérer toutes mes données depuis le cloud',
                ),
              ),
            ),
          ],
        ),
      ),
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
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
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
