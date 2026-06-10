import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/fridge_store.dart';
import '../data/shopping_list_store.dart';
import '../models/food.dart';
import '../models/shopping_item.dart';
import '../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Écran principal
// ---------------------------------------------------------------------------

class FridgeScreen extends StatefulWidget {
  const FridgeScreen({
    super.key,
    required this.store,
    required this.shoppingStore,
  });

  final FridgeStore store;
  final ShoppingListStore shoppingStore;

  @override
  State<FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends State<FridgeScreen> {
  final _searchController = TextEditingController();
  final Set<String> _selectedFoodIds = {};
  String _searchQuery = '';
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
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

  List<FoodItem> _filteredFoods(List<FoodItem> allFoods) {
    if (_searchQuery.isEmpty) return allFoods;
    return allFoods
        .where((food) => food.name.toLowerCase().contains(_searchQuery))
        .toList();
  }

  void _onAddFood() {
    _showFoodFormSheet();
  }

  void _startSelection([FoodItem? food]) {
    setState(() {
      _isSelectionMode = true;
      if (food != null) _selectedFoodIds.add(food.id);
    });
  }

  void _exitSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedFoodIds.clear();
    });
  }

  void _toggleFoodSelection(FoodItem food) {
    setState(() {
      _isSelectionMode = true;
      if (!_selectedFoodIds.add(food.id)) {
        _selectedFoodIds.remove(food.id);
      }
    });
  }

  void _toggleSelectAll(List<FoodItem> visibleFoods) {
    final visibleIds = visibleFoods.map((food) => food.id).toSet();
    final allVisibleSelected = visibleIds.every(_selectedFoodIds.contains);

    setState(() {
      if (allVisibleSelected) {
        _selectedFoodIds.removeAll(visibleIds);
      } else {
        _selectedFoodIds.addAll(visibleIds);
      }
    });
  }

  void _deleteSelectedFoods() {
    final allFoods = widget.store.foods;
    final deletedFoodsByIndex = <int, FoodItem>{
      for (var index = 0; index < allFoods.length; index++)
        if (_selectedFoodIds.contains(allFoods[index].id))
          index: allFoods[index],
    };
    if (deletedFoodsByIndex.isEmpty) return;

    final deletedIds = deletedFoodsByIndex.values
        .map((food) => food.id)
        .toList();
    final deletedCount = deletedIds.length;

    setState(() {
      _isSelectionMode = false;
      _selectedFoodIds.clear();
    });
    widget.store.deleteFoodsByIds(deletedIds);

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '$deletedCount aliment${deletedCount > 1 ? 's' : ''} '
          'supprimé${deletedCount > 1 ? 's' : ''} du frigo',
        ),
        action: SnackBarAction(
          label: 'Annuler',
          onPressed: () {
            widget.store.restoreFoodsAtIndices(deletedFoodsByIndex);
          },
        ),
      ),
    );
  }

  void _onFoodTap(FoodItem food) {
    if (_isSelectionMode) {
      _toggleFoodSelection(food);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _FoodDetailSheet(
          food: food,
          onEdit: () {
            Navigator.pop(sheetContext);
            _showFoodFormSheet(foodToEdit: food);
          },
          onDelete: () => _deleteFoodWithUndo(sheetContext, food),
          onAddToShoppingList: () => _addFoodToShoppingList(sheetContext, food),
          onConsumeAmount: () {
            Navigator.pop(sheetContext);
            _showConsumeAmountSheet(food);
          },
        );
      },
    );
  }

  void _addFoodToShoppingList(BuildContext sheetContext, FoodItem food) {
    widget.shoppingStore.addItem(
      ShoppingItem(
        id: 'fridge_${food.id}_${DateTime.now().millisecondsSinceEpoch}',
        name: food.name,
        amount: food.amount,
        unit: food.unit,
      ),
    );

    if (sheetContext.mounted) Navigator.pop(sheetContext);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text('${food.name} ajouté à la liste de courses'),
      ),
    );
  }

  Future<void> _showConsumeAmountSheet(FoodItem food) async {
    final amountToConsume = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ConsumeAmountSheet(food: food);
      },
    );

    if (amountToConsume == null || amountToConsume <= 0 || !mounted) return;

    widget.store.consumeFoodAmounts({food.id: amountToConsume});

    final isFullyConsumed = amountToConsume >= food.amount;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          isFullyConsumed
              ? '${food.name} retiré du frigo'
              : '${MeasurementHelper.label(amountToConsume, food.unit)} consommé',
        ),
      ),
    );
  }

  void _deleteFoodWithUndo(BuildContext sheetContext, FoodItem food) {
    final originalIndex = widget.store.foods.indexWhere(
      (item) => item.id == food.id,
    );
    if (originalIndex == -1) return;

    widget.store.deleteFood(food.id);
    if (sheetContext.mounted) Navigator.pop(sheetContext);

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text('${food.name} supprimé du frigo'),
        action: SnackBarAction(
          label: 'Annuler',
          onPressed: () {
            widget.store.restoreFood(food, index: originalIndex);
          },
        ),
      ),
    );
  }

  void _showFoodFormSheet({FoodItem? foodToEdit}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: _FoodFormSheet(
            foodToEdit: foodToEdit,
            onSave: (food) {
              if (foodToEdit == null) {
                widget.store.addFood(food);
              } else {
                widget.store.updateFood(food);
              }
              Navigator.pop(sheetContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  content: Text(
                    foodToEdit == null
                        ? '${food.name} ajouté au frigo'
                        : '${food.name} modifié',
                  ),
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
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allFoods = widget.store.foods;
    final filteredFoods = _filteredFoods(allFoods);
    final stats = FridgeStats.fromItems(allFoods);
    final isFridgeEmpty = allFoods.isEmpty;
    final hasSearchResults = filteredFoods.isNotEmpty;
    final selectedCount = _selectedFoodIds
        .where((id) => allFoods.any((food) => food.id == id))
        .length;
    final visibleIds = filteredFoods.map((food) => food.id).toSet();
    final allVisibleSelected =
        visibleIds.isNotEmpty && visibleIds.every(_selectedFoodIds.contains);

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(
                onPressed: _exitSelection,
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Quitter la sélection',
              )
            : null,
        title: Text(
          _isSelectionMode
              ? selectedCount == 0
                    ? 'Sélectionner'
                    : '$selectedCount sélectionné${selectedCount > 1 ? 's' : ''}'
              : 'Mon frigo',
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surfaceContainerLowest,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              onPressed: filteredFoods.isEmpty
                  ? null
                  : () => _toggleSelectAll(filteredFoods),
              icon: Icon(
                allVisibleSelected
                    ? Icons.deselect_rounded
                    : Icons.select_all_rounded,
              ),
              tooltip: allVisibleSelected
                  ? 'Tout désélectionner'
                  : 'Tout sélectionner',
            ),
            IconButton(
              onPressed: selectedCount == 0 ? null : _deleteSelectedFoods,
              icon: const Icon(Icons.delete_outline_rounded),
              color: colorScheme.error,
              tooltip: 'Supprimer la sélection',
            ),
          ] else if (!isFridgeEmpty)
            IconButton(
              onPressed: _startSelection,
              icon: const Icon(Icons.checklist_rounded),
              tooltip: 'Sélectionner des aliments',
            ),
        ],
      ),
      floatingActionButton: isFridgeEmpty || _isSelectionMode
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
                        _StatsCard(stats: stats),
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
                        return _FoodCard(
                          food: filteredFoods[index],
                          isSelectionMode: _isSelectionMode,
                          isSelected: _selectedFoodIds.contains(
                            filteredFoods[index].id,
                          ),
                          onTap: () => _onFoodTap(filteredFoods[index]),
                          onLongPress: () =>
                              _startSelection(filteredFoods[index]),
                        );
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
              icon: Icon(
                Icons.close_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
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
              label: 'Unités',
              color: colorScheme.primary,
            ),
          ),
          _VerticalDivider(color: colorScheme.outlineVariant),
          Expanded(
            child: _StatItem(
              icon: Icons.schedule_rounded,
              value: stats.expiringSoon.toString(),
              label: 'Bientôt',
              color: AppColors.expiringSoon,
            ),
          ),
          _VerticalDivider(color: colorScheme.outlineVariant),
          Expanded(
            child: _StatItem(
              icon: Icons.error_outline_rounded,
              value: stats.expired.toString(),
              label: 'Expirés',
              color: AppColors.expired,
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
    return Container(width: 1, height: 48, color: color.withValues(alpha: 0.6));
  }
}

class _FoodCard extends StatelessWidget {
  const _FoodCard({
    required this.food,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  final FoodItem food;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

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
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.55)
                : colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withValues(alpha: 0.45),
              width: isSelected ? 1.8 : 1,
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              food.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            food.amountLabel,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
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
                if (isSelectionMode)
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  )
                else
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
            'Ton frigo est vide',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ajoute tes premiers aliments pour suivre leurs dates de '
            'péremption et limiter le gaspillage.',
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

class _FoodDetailSheet extends StatelessWidget {
  const _FoodDetailSheet({
    required this.food,
    required this.onEdit,
    required this.onDelete,
    required this.onAddToShoppingList,
    required this.onConsumeAmount,
  });

  final FoodItem food;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddToShoppingList;
  final VoidCallback onConsumeAmount;

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
    final urgency = ExpiryHelper.urgencyFor(food.expiryDate);
    final urgencyColor = ExpiryHelper.colorFor(urgency);
    final urgencyBackground = ExpiryHelper.backgroundFor(urgency);
    final expiryLabel = ExpiryHelper.labelFor(food.expiryDate);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
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
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: urgencyBackground,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      food.emoji,
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          food.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
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
                          child: Text(
                            expiryLabel,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: urgencyColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _DetailRow(
                icon: Icons.category_outlined,
                label: 'Catégorie',
                value: FoodCategoryHelper.label(food.category),
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.inventory_2_outlined,
                label: 'Quantité',
                value: food.amountLabel,
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.event_outlined,
                label: 'Date d’expiration',
                value: _formatExpiryDate(food.expiryDate),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onConsumeAmount,
                icon: const Icon(Icons.restaurant_rounded),
                label: const Text('Consommer une partie'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onAddToShoppingList,
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: const Text('Ajouter à ma liste de courses'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Modifier'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, color: colorScheme.error),
                label: Text(
                  'Supprimer',
                  style: TextStyle(color: colorScheme.error),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(
                    color: colorScheme.error.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsumeAmountSheet extends StatefulWidget {
  const _ConsumeAmountSheet({required this.food});

  final FoodItem food;

  @override
  State<_ConsumeAmountSheet> createState() => _ConsumeAmountSheetState();
}

class _ConsumeAmountSheetState extends State<_ConsumeAmountSheet> {
  late double _amount;

  double get _step => MeasurementHelper.stepFor(widget.food.unit);

  @override
  void initState() {
    super.initState();
    _amount = math.min(_step, widget.food.amount);
  }

  void _incrementAmount() {
    setState(() {
      _amount = math.min(widget.food.amount, _amount + _step);
    });
  }

  void _decrementAmount() {
    setState(() {
      _amount = math.max(_step, _amount - _step);
      if (_amount > widget.food.amount) {
        _amount = widget.food.amount;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final remainingAmount = widget.food.amount - _amount;
    final consumesAll = remainingAmount <= 0;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
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
                'Consommer ${widget.food.name}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Quantité disponible : ${widget.food.amountLabel}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quantité consommée',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            MeasurementHelper.label(_amount, widget.food.unit),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            consumesAll
                                ? 'L’aliment sera retiré du frigo.'
                                : 'Restera ${MeasurementHelper.label(remainingAmount, widget.food.unit)}.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _FridgeQuantityStepper(
                      amountLabel: '',
                      canDecrement: _amount > _step,
                      onDecrement: _decrementAmount,
                      onIncrement: _amount >= widget.food.amount
                          ? () {}
                          : _incrementAmount,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, _amount),
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  consumesAll ? 'Tout consommer' : 'Valider la consommation',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.onSurfaceVariant, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodFormSheet extends StatefulWidget {
  const _FoodFormSheet({required this.onSave, this.foodToEdit});

  final void Function(FoodItem food) onSave;
  final FoodItem? foodToEdit;

  @override
  State<_FoodFormSheet> createState() => _FoodFormSheetState();
}

class _FoodFormSheetState extends State<_FoodFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  late FoodCategory _category;
  late DateTime _expiryDate;
  late double _amount;
  late String _unit;

  bool get _isEditing => widget.foodToEdit != null;

  @override
  void initState() {
    super.initState();
    final food = widget.foodToEdit;
    _nameController = TextEditingController(text: food?.name ?? '');
    _category = food?.category ?? FoodCategory.other;
    _amount = food?.amount ?? 1;
    _unit = food?.unit ?? 'unité';
    _expiryDate =
        food?.expiryDate ??
        DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        ).add(const Duration(days: 7));
  }

  void _incrementAmount() {
    setState(() => _amount += MeasurementHelper.stepFor(_unit));
  }

  void _decrementAmount() {
    final nextAmount = _amount - MeasurementHelper.stepFor(_unit);
    if (nextAmount <= 0) return;
    setState(() => _amount = nextAmount);
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
      id:
          widget.foodToEdit?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      emoji: FoodCategoryHelper.emoji(_category),
      expiryDate: _expiryDate,
      category: _category,
      quantity: MeasurementHelper.logicalQuantity(_amount, _unit),
      amount: _amount,
      unit: _unit,
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
                  _isEditing ? 'Modifier l’aliment' : 'Ajouter un aliment',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isEditing
                      ? 'Met à jour les informations de cet aliment.'
                      : 'Renseignez les informations pour suivre la péremption.',
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
                InputDecorator(
                  decoration: _sheetInputDecoration(
                    context,
                    label: 'Quantité',
                    prefixIcon: Icons.inventory_2_outlined,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              MeasurementHelper.label(_amount, _unit),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          _FridgeQuantityStepper(
                            amountLabel: MeasurementHelper.label(
                              _amount,
                              _unit,
                            ),
                            canDecrement:
                                _amount > MeasurementHelper.stepFor(_unit),
                            onDecrement: _decrementAmount,
                            onIncrement: _incrementAmount,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _unit,
                        decoration: const InputDecoration(
                          labelText: 'Unité',
                          border: OutlineInputBorder(),
                        ),
                        items: MeasurementHelper.units
                            .map(
                              (unit) => DropdownMenuItem<String>(
                                value: unit,
                                child: Text(unit),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _amount = MeasurementHelper.amountAfterUnitChange(
                              _amount,
                              fromUnit: _unit,
                              toUnit: value,
                            );
                            _unit = value;
                          });
                        },
                      ),
                    ],
                  ),
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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

class _FridgeQuantityStepper extends StatelessWidget {
  const _FridgeQuantityStepper({
    required this.amountLabel,
    required this.canDecrement,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String amountLabel;
  final bool canDecrement;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: canDecrement ? onDecrement : null,
            icon: const Icon(Icons.remove_rounded),
            tooltip: 'Diminuer',
            visualDensity: VisualDensity.compact,
            iconSize: 20,
          ),
          SizedBox(
            width: 72,
            child: Text(
              amountLabel,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Augmenter',
            visualDensity: VisualDensity.compact,
            iconSize: 20,
          ),
        ],
      ),
    );
  }
}
