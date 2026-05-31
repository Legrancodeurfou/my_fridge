import 'package:flutter/material.dart';

import '../data/fridge_store.dart';
import '../models/food.dart';
import 'recipes_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.store,
    required this.onNavigateToTab,
  });

  final FridgeStore store;
  final void Function(int tabIndex) onNavigateToTab;

  static const fridgeTabIndex = 1;
  static const scanTabIndex = 2;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => _HomeContent(
        foods: store.foods,
        onNavigateToTab: onNavigateToTab,
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.foods,
    required this.onNavigateToTab,
  });

  final List<FoodItem> foods;
  final void Function(int tabIndex) onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final stats = FridgeStats.fromItems(foods);
    final recipeCount = RecipeCatalog.suggestFor(foods).length;
    final expiringSoonFoods = _expiringSoonFoods(foods);

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
            'Bonjour Esteban 👋',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Voici le résumé de ton frigo aujourd’hui.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _SummaryStatsCard(
            totalFoods: stats.total,
            expiringSoon: stats.expiringSoon,
            recipeCount: recipeCount,
          ),
          const SizedBox(height: 28),
          Text(
            'Actions rapides',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
          _QuickActionCard(
            icon: Icons.kitchen_outlined,
            title: 'Voir mon frigo',
            subtitle: stats.total == 0
                ? 'Commence à remplir ton inventaire'
                : '${stats.total} aliment${stats.total > 1 ? 's' : ''} en stock',
            color: colorScheme.primary,
            onTap: () => onNavigateToTab(HomeScreen.fridgeTabIndex),
          ),
          const SizedBox(height: 12),
          _QuickActionCard(
            icon: Icons.document_scanner_outlined,
            title: 'Scanner un ticket',
            subtitle: 'Ajoute plusieurs produits en un clic',
            color: const Color(0xFF00897B),
            onTap: () => onNavigateToTab(HomeScreen.scanTabIndex),
          ),
          if (expiringSoonFoods.isNotEmpty) ...[
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'À consommer bientôt',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => onNavigateToTab(HomeScreen.fridgeTabIndex),
                  child: const Text('Voir tout'),
                ),
              ],
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

  List<FoodItem> _expiringSoonFoods(List<FoodItem> items) {
    final urgent = items.where((food) {
      final days = ExpiryHelper.daysUntilExpiry(food.expiryDate);
      return days < 3;
    }).toList();

    urgent.sort(
      (a, b) => ExpiryHelper.daysUntilExpiry(a.expiryDate)
          .compareTo(ExpiryHelper.daysUntilExpiry(b.expiryDate)),
    );

    return urgent.take(4).toList();
  }
}

class _SummaryStatsCard extends StatelessWidget {
  const _SummaryStatsCard({
    required this.totalFoods,
    required this.expiringSoon,
    required this.recipeCount,
  });

  final int totalFoods;
  final int expiringSoon;
  final int recipeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
              label: 'Aliments',
              color: colorScheme.primary,
            ),
          ),
          _HomeDivider(color: colorScheme.outlineVariant),
          Expanded(
            child: _StatColumn(
              icon: Icons.schedule_rounded,
              value: expiringSoon.toString(),
              label: 'Bientôt',
              color: const Color(0xFFFB8C00),
            ),
          ),
          _HomeDivider(color: colorScheme.outlineVariant),
          Expanded(
            child: _StatColumn(
              icon: Icons.restaurant_menu_outlined,
              value: recipeCount.toString(),
              label: 'Recettes',
              color: const Color(0xFF43A047),
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
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
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
    return Container(
      width: 1,
      height: 48,
      color: color.withValues(alpha: 0.6),
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
                color: colorScheme.shadow.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
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
    final expiryLabel = ExpiryHelper.labelFor(food.expiryDate);

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
            child: Text(food.emoji, style: const TextStyle(fontSize: 22)),
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
          Icon(
            Icons.warning_amber_rounded,
            color: urgencyColor,
            size: 22,
          ),
        ],
      ),
    );
  }
}
