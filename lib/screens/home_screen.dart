import 'package:flutter/material.dart';

import '../data/fridge_store.dart';
import '../data/profile_store.dart';
import '../data/scan_history_store.dart';
import '../data/shopping_list_store.dart';
import '../models/food.dart';
import '../models/scan_history_item.dart';
import '../theme/app_theme.dart';
import 'recipes_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.store,
    required this.profileStore,
    required this.shoppingListStore,
    required this.scanHistoryStore,
    required this.onNavigateToTab,
    required this.onOpenStockSetup,
  });

  final FridgeStore store;
  final ProfileStore profileStore;
  final ShoppingListStore shoppingListStore;
  final ScanHistoryStore scanHistoryStore;
  final void Function(int tabIndex) onNavigateToTab;
  final VoidCallback onOpenStockSetup;

  static const fridgeTabIndex = 1;
  static const scanTabIndex = 2;
  static const recipesTabIndex = 3;
  static const shoppingTabIndex = 4;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        store,
        profileStore,
        shoppingListStore,
        scanHistoryStore,
      ]),
      builder: (context, _) => _HomeContent(
        foods: store.foods,
        profile: profileStore.profile,
        shoppingItemsCount: shoppingListStore.items.length,
        checkedShoppingItemsCount: shoppingListStore.items
            .where((item) => item.isChecked)
            .length,
        latestScan: scanHistoryStore.items.isEmpty
            ? null
            : scanHistoryStore.items.first,
        onNavigateToTab: onNavigateToTab,
        onOpenStockSetup: onOpenStockSetup,
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.foods,
    required this.profile,
    required this.shoppingItemsCount,
    required this.checkedShoppingItemsCount,
    required this.latestScan,
    required this.onNavigateToTab,
    required this.onOpenStockSetup,
  });

  final List<FoodItem> foods;
  final ProfileData profile;
  final int shoppingItemsCount;
  final int checkedShoppingItemsCount;
  final ScanHistoryItem? latestScan;
  final void Function(int tabIndex) onNavigateToTab;
  final VoidCallback onOpenStockSetup;

  int get _pendingShoppingItemsCount =>
      shoppingItemsCount - checkedShoppingItemsCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final stats = FridgeStats.fromItems(foods);
    final suggestedRecipes = RecipeCatalog.suggestFor(foods, profile: profile);
    final feasibleRecipeCount = suggestedRecipes
        .where(
          (recipe) => RecipeCatalog.matchIngredients(
            recipe,
            foods,
          ).every((match) => match.isAvailable),
        )
        .length;
    final expiringSoonFoods = _expiringSoonFoods(foods);
    final smartActions = _buildSmartActions(
      context: context,
      stats: stats,
      feasibleRecipeCount: feasibleRecipeCount,
      suggestedRecipeCount: suggestedRecipes.length,
      expiringSoonFoods: expiringSoonFoods,
    );
    final firstName = profile.name.trim();

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Accueil'),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surfaceContainerLowest,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            firstName.isEmpty ? 'Bonjour 👋' : 'Bonjour $firstName 👋',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ton assistant anti-gaspi te résume les actions utiles du moment.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (foods.length <= 3) ...[
            const SizedBox(height: 20),
            _StockSetupPromptCard(onTap: onOpenStockSetup),
          ],
          const SizedBox(height: 24),
          _SummaryStatsCard(
            totalFoods: stats.total,
            expiringSoon: stats.expiringSoon,
            recipeCount: feasibleRecipeCount,
            shoppingCount: _pendingShoppingItemsCount,
          ),
          if (smartActions.isNotEmpty) ...[
            const SizedBox(height: 28),
            _SectionHeader(
              title: 'À faire maintenant',
              actionLabel: null,
              onActionTap: null,
            ),
            const SizedBox(height: 12),
            ...smartActions,
          ],
          const SizedBox(height: 28),
          _SectionHeader(
            title: 'Actions rapides',
            actionLabel: null,
            onActionTap: null,
          ),
          const SizedBox(height: 12),
          _QuickActionCard(
            icon: Icons.kitchen_outlined,
            title: 'Voir mon frigo',
            subtitle: stats.total == 0
                ? 'Commence à remplir ton inventaire'
                : '${stats.total} unité${stats.total > 1 ? 's' : ''} en stock',
            color: colorScheme.primary,
            onTap: () => onNavigateToTab(HomeScreen.fridgeTabIndex),
          ),
          if (foods.length > 3) ...[
            const SizedBox(height: 12),
            _QuickActionCard(
              icon: Icons.inventory_2_outlined,
              title: 'Remplir mon stock',
              subtitle: 'Ajoute rapidement des aliments zone par zone',
              color: colorScheme.primary,
              onTap: onOpenStockSetup,
            ),
          ],
          const SizedBox(height: 12),
          _QuickActionCard(
            icon: Icons.document_scanner_outlined,
            title: 'Scanner un ticket',
            subtitle: 'Ajoute plusieurs produits en un clic',
            color: AppColors.primary,
            onTap: () => onNavigateToTab(HomeScreen.scanTabIndex),
          ),
          const SizedBox(height: 12),
          _QuickActionCard(
            icon: Icons.restaurant_menu_rounded,
            title: 'Voir les recettes',
            subtitle: feasibleRecipeCount > 0
                ? '$feasibleRecipeCount recette'
                      '${feasibleRecipeCount > 1 ? 's' : ''} faisable'
                      '${feasibleRecipeCount > 1 ? 's' : ''} maintenant'
                : suggestedRecipes.isEmpty
                ? 'Ajoute des aliments non expirés pour obtenir des idées'
                : 'Découvre les idées à compléter avec quelques ingrédients',
            color: AppColors.primary,
            onTap: () => onNavigateToTab(HomeScreen.recipesTabIndex),
          ),
          if (expiringSoonFoods.isNotEmpty) ...[
            const SizedBox(height: 28),
            _SectionHeader(
              title: 'À consommer bientôt',
              actionLabel: 'Voir tout',
              onActionTap: () => onNavigateToTab(HomeScreen.fridgeTabIndex),
            ),
            const SizedBox(height: 8),
            ...expiringSoonFoods.map(
              (food) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ExpiringFoodTile(food: food),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildSmartActions({
    required BuildContext context,
    required FridgeStats stats,
    required int feasibleRecipeCount,
    required int suggestedRecipeCount,
    required List<FoodItem> expiringSoonFoods,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final actions = <Widget>[];

    if (stats.expired > 0) {
      actions.add(
        _SmartActionCard(
          icon: Icons.error_outline_rounded,
          title:
              '${stats.expired} aliment${stats.expired > 1 ? 's' : ''} expiré${stats.expired > 1 ? 's' : ''}',
          subtitle: 'Vérifie ton frigo et retire ce qui n’est plus bon.',
          color: colorScheme.error,
          onTap: () => onNavigateToTab(HomeScreen.fridgeTabIndex),
        ),
      );
    } else if (stats.expiringSoon > 0) {
      actions.add(
        _SmartActionCard(
          icon: Icons.schedule_rounded,
          title:
              '${stats.expiringSoon} aliment${stats.expiringSoon > 1 ? 's' : ''} à consommer vite',
          subtitle: expiringSoonFoods.isEmpty
              ? 'Va voir ce qui approche de la date limite.'
              : 'Priorité : ${expiringSoonFoods.first.name}.',
          color: AppColors.expiringSoon,
          onTap: () => onNavigateToTab(HomeScreen.fridgeTabIndex),
        ),
      );
    }

    if (feasibleRecipeCount > 0) {
      actions.add(
        _SmartActionCard(
          icon: Icons.restaurant_menu_rounded,
          title:
              '$feasibleRecipeCount recette'
              '${feasibleRecipeCount > 1 ? 's' : ''} faisable'
              '${feasibleRecipeCount > 1 ? 's' : ''} maintenant',
          subtitle: 'Tous les ingrédients nécessaires sont disponibles.',
          color: AppColors.primary,
          onTap: () => onNavigateToTab(HomeScreen.recipesTabIndex),
        ),
      );
    } else if (suggestedRecipeCount > 0) {
      actions.add(
        _SmartActionCard(
          icon: Icons.restaurant_menu_rounded,
          title: 'Des idées recettes à compléter',
          subtitle: 'Aucune recette n’est entièrement faisable pour l’instant.',
          color: AppColors.expiringSoon,
          onTap: () => onNavigateToTab(HomeScreen.recipesTabIndex),
        ),
      );
    }

    if (_pendingShoppingItemsCount > 0) {
      actions.add(
        _SmartActionCard(
          icon: Icons.shopping_cart_rounded,
          title:
              '$_pendingShoppingItemsCount article${_pendingShoppingItemsCount > 1 ? 's' : ''} à acheter',
          subtitle: checkedShoppingItemsCount > 0
              ? '$checkedShoppingItemsCount déjà coché${checkedShoppingItemsCount > 1 ? 's' : ''}.'
              : 'Complète ta liste avant les courses.',
          color: colorScheme.primary,
          onTap: () => onNavigateToTab(HomeScreen.shoppingTabIndex),
        ),
      );
    }

    if (latestScan != null) {
      actions.add(
        _SmartActionCard(
          icon: Icons.receipt_long_rounded,
          title: 'Dernier scan ${_relativeScanLabel(latestScan!.scannedAt)}',
          subtitle: latestScan!.summary,
          color: AppColors.textSecondary,
          onTap: () => onNavigateToTab(HomeScreen.scanTabIndex),
        ),
      );
    }

    if (actions.isEmpty) {
      actions.add(
        _SmartActionCard(
          icon: Icons.document_scanner_outlined,
          title: 'Commence par scanner un ticket',
          subtitle: 'Ajoute rapidement les produits de tes dernières courses.',
          color: AppColors.primary,
          onTap: () => onNavigateToTab(HomeScreen.scanTabIndex),
        ),
      );
    }

    return [
      for (final action in actions.take(4)) ...[
        action,
        const SizedBox(height: 12),
      ],
    ];
  }

  List<FoodItem> _expiringSoonFoods(List<FoodItem> items) {
    final urgent = items.where((food) {
      final days = ExpiryHelper.daysUntilExpiry(food.expiryDate);
      return days >= 0 && days < 3;
    }).toList();

    urgent.sort(
      (a, b) => ExpiryHelper.daysUntilExpiry(
        a.expiryDate,
      ).compareTo(ExpiryHelper.daysUntilExpiry(b.expiryDate)),
    );

    return urgent.take(4).toList();
  }

  String _relativeScanLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scanDay = DateTime(date.year, date.month, date.day);
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    if (scanDay == today) return 'aujourd’hui à $hour:$minute';
    if (scanDay == today.subtract(const Duration(days: 1))) {
      return 'hier à $hour:$minute';
    }

    return 'le ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} à $hour:$minute';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onActionTap,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onActionTap, child: Text(actionLabel!)),
      ],
    );
  }
}

class _SummaryStatsCard extends StatelessWidget {
  const _SummaryStatsCard({
    required this.totalFoods,
    required this.expiringSoon,
    required this.recipeCount,
    required this.shoppingCount,
  });

  final int totalFoods;
  final int expiringSoon;
  final int recipeCount;
  final int shoppingCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatColumn(
              icon: Icons.inventory_2_outlined,
              value: totalFoods.toString(),
              label: 'Unités',
              color: colorScheme.primary,
            ),
          ),
          _HomeDivider(color: colorScheme.outlineVariant),
          Expanded(
            child: _StatColumn(
              icon: Icons.schedule_rounded,
              value: expiringSoon.toString(),
              label: 'Bientôt',
              color: AppColors.expiringSoon,
            ),
          ),
          _HomeDivider(color: colorScheme.outlineVariant),
          Expanded(
            child: _StatColumn(
              icon: Icons.restaurant_menu_outlined,
              value: recipeCount.toString(),
              label: 'Faisables',
              color: AppColors.primary,
            ),
          ),
          _HomeDivider(color: colorScheme.outlineVariant),
          Expanded(
            child: _StatColumn(
              icon: Icons.shopping_cart_outlined,
              value: shoppingCount.toString(),
              label: 'Courses',
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 21),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _HomeDivider extends StatelessWidget {
  const _HomeDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 48, color: color.withValues(alpha: 0.6));
  }
}

class _StockSetupPromptCard extends StatelessWidget {
  const _StockSetupPromptCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Commence par remplir ton stock',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Ajoute ce que tu as déjà chez toi pour obtenir de meilleures '
            'recettes et éviter le gaspillage.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Mise en route'),
          ),
        ],
      ),
    );
  }
}

class _SmartActionCard extends StatelessWidget {
  const _SmartActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.07),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.07),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpiringFoodTile extends StatelessWidget {
  const _ExpiringFoodTile({required this.food});

  final FoodItem food;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final urgency = ExpiryHelper.urgencyFor(food.expiryDate);
    final urgencyColor = ExpiryHelper.colorFor(urgency);
    final urgencyBackground = ExpiryHelper.backgroundFor(urgency);
    final expiryLabel =
        '${food.amountLabel} • ${ExpiryHelper.labelFor(food.expiryDate)}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: urgencyBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              FoodCategoryHelper.icon(food.category),
              size: 22,
              color: urgencyColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  expiryLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: urgencyColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.warning_amber_rounded, color: urgencyColor, size: 22),
        ],
      ),
    );
  }
}
