import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Couche données — remplaçable par une base locale ou un repository réel.
// ---------------------------------------------------------------------------

enum ExpiryUrgency { expired, warning, safe }

class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.expiryDate,
    this.category = FoodCategory.other,
  });

  final String id;
  final String name;
  final String emoji;
  final DateTime expiryDate;
  final FoodCategory category;
}

enum FoodCategory { dairy, produce, meat, other }

abstract final class FoodCategoryHelper {
  static String label(FoodCategory category) {
    return switch (category) {
      FoodCategory.dairy => 'Produits laitiers',
      FoodCategory.produce => 'Fruits & légumes',
      FoodCategory.meat => 'Viande & poisson',
      FoodCategory.other => 'Autre',
    };
  }

  static String emoji(FoodCategory category) {
    return switch (category) {
      FoodCategory.dairy => '🥛',
      FoodCategory.produce => '🥬',
      FoodCategory.meat => '🥩',
      FoodCategory.other => '🍽️',
    };
  }
}

/// Source de données fictive. Remplacer `fetchAll()` par un appel repository.
abstract final class FridgeMockDataSource {
  static List<FoodItem> fetchAll() {
    final today = _today;

    return [
      FoodItem(
        id: '1',
        name: 'Lait',
        emoji: '🥛',
        expiryDate: today.add(const Duration(days: 3)),
        category: FoodCategory.dairy,
      ),
      FoodItem(
        id: '2',
        name: 'Tomates',
        emoji: '🍅',
        expiryDate: today.add(const Duration(days: 1)),
        category: FoodCategory.produce,
      ),
      FoodItem(
        id: '3',
        name: 'Emmental',
        emoji: '🧀',
        expiryDate: today.add(const Duration(days: 12)),
        category: FoodCategory.dairy,
      ),
      FoodItem(
        id: '4',
        name: 'Steak haché',
        emoji: '🥩',
        expiryDate: today,
        category: FoodCategory.meat,
      ),
      FoodItem(
        id: '5',
        name: 'Œufs',
        emoji: '🥚',
        expiryDate: today.add(const Duration(days: 6)),
        category: FoodCategory.dairy,
      ),
      FoodItem(
        id: '6',
        name: 'Yaourt nature',
        emoji: '🥣',
        expiryDate: today.subtract(const Duration(days: 2)),
        category: FoodCategory.dairy,
      ),
    ];
  }

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

class FridgeStats {
  const FridgeStats({
    required this.total,
    required this.expiringSoon,
    required this.expired,
  });

  final int total;
  final int expiringSoon;
  final int expired;

  factory FridgeStats.fromItems(List<FoodItem> items) {
    var expiringSoon = 0;
    var expired = 0;

    for (final item in items) {
      final days = ExpiryHelper.daysUntilExpiry(item.expiryDate);
      if (days < 0) {
        expired++;
      } else if (days < 3) {
        expiringSoon++;
      }
    }

    return FridgeStats(
      total: items.length,
      expiringSoon: expiringSoon,
      expired: expired,
    );
  }
}

abstract final class ExpiryHelper {
  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static int daysUntilExpiry(DateTime expiryDate) {
    final normalized =
        DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return normalized.difference(_today).inDays;
  }

  static ExpiryUrgency urgencyFor(DateTime expiryDate) {
    final days = daysUntilExpiry(expiryDate);
    if (days <= 0) return ExpiryUrgency.expired;
    if (days < 3) return ExpiryUrgency.warning;
    return ExpiryUrgency.safe;
  }

  static Color colorFor(ExpiryUrgency urgency) {
    return switch (urgency) {
      ExpiryUrgency.expired => const Color(0xFFE53935),
      ExpiryUrgency.warning => const Color(0xFFFB8C00),
      ExpiryUrgency.safe => const Color(0xFF43A047),
    };
  }

  static Color backgroundFor(ExpiryUrgency urgency) {
    return colorFor(urgency).withValues(alpha: 0.12);
  }

  static String labelFor(DateTime expiryDate) {
    final days = daysUntilExpiry(expiryDate);

    if (days < 0) {
      final overdue = days.abs();
      return overdue == 1 ? 'Expiré hier' : 'Expiré il y a $overdue jours';
    }
    if (days == 0) return 'Expire aujourd’hui';
    if (days == 1) return 'Expire demain';
    return 'Expire dans $days jours';
  }

  static IconData iconForCategory(FoodCategory category) {
    return switch (category) {
      FoodCategory.dairy => Icons.egg_alt_outlined,
      FoodCategory.produce => Icons.eco_outlined,
      FoodCategory.meat => Icons.set_meal_outlined,
      FoodCategory.other => Icons.restaurant_outlined,
    };
  }
}

// ---------------------------------------------------------------------------
// Écran principal
// ---------------------------------------------------------------------------

class FridgeScreen extends StatefulWidget {
  const FridgeScreen({super.key});

  @override
  State<FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends State<FridgeScreen> {
  late List<FoodItem> _allFoods;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _allFoods = FridgeMockDataSource.fetchAll();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
  }

  List<FoodItem> get _filteredFoods {
    if (_searchQuery.isEmpty) return _allFoods;
    return _allFoods
        .where((food) => food.name.toLowerCase().contains(_searchQuery))
        .toList();
  }

  FridgeStats get _stats => FridgeStats.fromItems(_allFoods);

  void _onAddFood() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: _AddFoodSheet(
            onSave: (food) {
              setState(() => _allFoods = [food, ..._allFoods]);
              Navigator.pop(sheetContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  content: Text('${food.name} ajouté au frigo'),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filteredFoods = _filteredFoods;
    final isFridgeEmpty = _allFoods.isEmpty;
    final hasSearchResults = filteredFoods.isNotEmpty;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Mon Frigo'),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surfaceContainerLowest,
      ),
      floatingActionButton: isFridgeEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _onAddFood,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter'),
            ),
      body: isFridgeEmpty
          ? _EmptyFridgeView(onAdd: _onAddFood)
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SearchField(controller: _searchController),
                        const SizedBox(height: 16),
                        _StatsCard(stats: _stats),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Aliments disponibles',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!hasSearchResults)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _NoSearchResultsView(
                      query: _searchController.text.trim(),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverList.separated(
                      itemCount: filteredFoods.length,
                      separatorBuilder: (context, _) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _FoodCard(food: filteredFoods[index]);
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Composants UI
// ---------------------------------------------------------------------------

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Rechercher un aliment...',
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: colorScheme.onSurfaceVariant,
        ),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: Icon(Icons.close_rounded, color: colorScheme.onSurfaceVariant),
              onPressed: controller.clear,
              tooltip: 'Effacer',
            );
          },
        ),
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final FridgeStats stats;

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
            child: _StatItem(
              icon: Icons.inventory_2_outlined,
              value: stats.total.toString(),
              label: 'Total',
              color: colorScheme.primary,
            ),
          ),
          _VerticalDivider(color: colorScheme.outlineVariant),
          Expanded(
            child: _StatItem(
              icon: Icons.schedule_rounded,
              value: stats.expiringSoon.toString(),
              label: 'Bientôt',
              color: const Color(0xFFFB8C00),
            ),
          ),
          _VerticalDivider(color: colorScheme.outlineVariant),
          Expanded(
            child: _StatItem(
              icon: Icons.error_outline_rounded,
              value: stats.expired.toString(),
              label: 'Expirés',
              color: const Color(0xFFE53935),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
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

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider({required this.color});

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

class _FoodCard extends StatelessWidget {
  const _FoodCard({required this.food});

  final FoodItem food;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final urgency = ExpiryHelper.urgencyFor(food.expiryDate);
    final urgencyColor = ExpiryHelper.colorFor(urgency);
    final urgencyBackground = ExpiryHelper.backgroundFor(urgency);
    final expiryLabel = ExpiryHelper.labelFor(food.expiryDate);

    return Material(
      color: colorScheme.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () {},
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
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: urgencyBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(food.emoji, style: const TextStyle(fontSize: 28)),
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Icon(
                          ExpiryHelper.iconForCategory(food.category),
                          size: 14,
                          color: urgencyColor.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: urgencyBackground,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              urgency == ExpiryUrgency.safe
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.access_time_rounded,
                              size: 14,
                              color: urgencyColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              expiryLabel,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: urgencyColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
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

class _EmptyFridgeView extends StatelessWidget {
  const _EmptyFridgeView({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.kitchen_outlined,
              size: 56,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Votre frigo est vide',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ajoutez vos premiers aliments pour suivre leurs dates de péremption et limiter le gaspillage.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Ajouter un aliment'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddFoodSheet extends StatefulWidget {
  const _AddFoodSheet({required this.onSave});

  final void Function(FoodItem food) onSave;

  @override
  State<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<_AddFoodSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  FoodCategory _category = FoodCategory.other;
  late DateTime _expiryDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _expiryDate = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      helpText: 'Date d’expiration',
      cancelText: 'Annuler',
      confirmText: 'OK',
    );
    if (picked != null) {
      setState(() {
        _expiryDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final food = FoodItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      emoji: FoodCategoryHelper.emoji(_category),
      expiryDate: _expiryDate,
      category: _category,
    );

    widget.onSave(food);
  }

  String _formatExpiryDate(DateTime date) {
    const months = [
      'janv.',
      'févr.',
      'mars',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sept.',
      'oct.',
      'nov.',
      'déc.',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Ajouter un aliment',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Renseignez les informations pour suivre la péremption.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: _sheetInputDecoration(
                    context,
                    label: 'Nom de l’aliment',
                    hint: 'Ex. Lait, Tomates, Poulet…',
                    prefixIcon: Icons.label_outline_rounded,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Indiquez un nom d’aliment';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<FoodCategory>(
                  initialValue: _category,
                  decoration: _sheetInputDecoration(
                    context,
                    label: 'Catégorie',
                    prefixIcon: Icons.category_outlined,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  items: FoodCategory.values
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Row(
                            children: [
                              Text(
                                FoodCategoryHelper.emoji(category),
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 10),
                              Text(FoodCategoryHelper.label(category)),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _category = value);
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickExpiryDate,
                  borderRadius: BorderRadius.circular(16),
                  child: InputDecorator(
                    decoration: _sheetInputDecoration(
                      context,
                      label: 'Date d’expiration',
                      prefixIcon: Icons.event_outlined,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _formatExpiryDate(_expiryDate),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.calendar_month_rounded,
                          color: colorScheme.primary,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Enregistrer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _sheetInputDecoration(
    BuildContext context, {
    required String label,
    String? hint,
    IconData? prefixIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: colorScheme.onSurfaceVariant)
          : null,
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.error, width: 1.5),
      ),
    );
  }
}

class _NoSearchResultsView extends StatelessWidget {
  const _NoSearchResultsView({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 56,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun résultat',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            query.isEmpty
                ? 'Essayez un autre terme de recherche.'
                : 'Aucun aliment ne correspond à « $query ».',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
