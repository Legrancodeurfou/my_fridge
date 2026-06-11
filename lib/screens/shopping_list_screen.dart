import 'package:flutter/material.dart';

import '../data/fridge_store.dart';
import '../data/shopping_list_store.dart';
import '../models/food.dart';
import '../models/shopping_item.dart';

class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({
    super.key,
    required this.shoppingStore,
    required this.fridgeStore,
  });

  final ShoppingListStore shoppingStore;
  final FridgeStore fridgeStore;
  static const _deletionSnackBarDuration = Duration(seconds: 4);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: shoppingStore,
      builder: (context, _) {
        final items = shoppingStore.items;
        final checkedItems = items.where((item) => item.isChecked).toList();
        final checkedCount = checkedItems.length;

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          appBar: AppBar(
            title: const Text('Liste de courses'),
            centerTitle: false,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerLowest,
            actions: [
              if (items.isNotEmpty)
                PopupMenuButton<_ShoppingAction>(
                  onSelected: (action) {
                    if (action == _ShoppingAction.addCheckedToFridge) {
                      _showAddCheckedToFridgeSheet(context, checkedItems);
                    } else if (action == _ShoppingAction.clearChecked) {
                      shoppingStore.clearChecked();
                    } else if (action == _ShoppingAction.clearAll) {
                      _confirmClearAll(context);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _ShoppingAction.addCheckedToFridge,
                      enabled: checkedCount > 0,
                      child: Text('Ajouter au frigo ($checkedCount)'),
                    ),
                    PopupMenuItem(
                      value: _ShoppingAction.clearChecked,
                      enabled: checkedCount > 0,
                      child: Text('Supprimer cochés ($checkedCount)'),
                    ),
                    const PopupMenuItem(
                      value: _ShoppingAction.clearAll,
                      child: Text('Tout vider'),
                    ),
                  ],
                ),
            ],
          ),
          body: items.isEmpty
              ? const _EmptyShoppingListView()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: items.length + 1,
                  separatorBuilder: (context, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _ShoppingListHeader(
                        totalCount: items.length,
                        checkedCount: checkedCount,
                        onAddCheckedToFridge: checkedCount == 0
                            ? null
                            : () => _showAddCheckedToFridgeSheet(
                                context,
                                checkedItems,
                              ),
                        onClearChecked: checkedCount == 0
                            ? null
                            : shoppingStore.clearChecked,
                        onClearAll: () => _confirmClearAll(context),
                      );
                    }

                    final item = items[index - 1];
                    return _ShoppingItemCard(
                      item: item,
                      onToggle: () => shoppingStore.toggleItem(item.id),
                      onDelete: () =>
                          _deleteItemWithUndo(context, item, index - 1),
                    );
                  },
                ),
        );
      },
    );
  }

  void _deleteItemWithUndo(
    BuildContext context,
    ShoppingItem item,
    int originalIndex,
  ) {
    shoppingStore.deleteItem(item.id);

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: _deletionSnackBarDuration,
        persist: false,
        content: Text('${item.name} supprimé des courses'),
        action: SnackBarAction(
          label: 'Annuler',
          onPressed: () {
            shoppingStore.restoreItem(item, index: originalIndex);
          },
        ),
      ),
    );
  }

  Future<void> _showAddCheckedToFridgeSheet(
    BuildContext context,
    List<ShoppingItem> checkedItems,
  ) async {
    if (checkedItems.isEmpty) return;

    final drafts = await showModalBottomSheet<List<_PurchasedDraft>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _AddCheckedToFridgeSheet(items: checkedItems);
      },
    );

    if (drafts == null || drafts.isEmpty || !context.mounted) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final foods = <FoodItem>[
      for (var i = 0; i < drafts.length; i++) drafts[i].toFoodItem('$now-$i'),
    ];

    fridgeStore.addFoods(foods);
    shoppingStore.deleteItemsByIds(
      drafts.map((draft) => draft.item.id).toList(),
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          foods.length == 1
              ? '${foods.first.name} ajouté au frigo'
              : '${foods.length} produits ajoutés au frigo',
        ),
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Vider la liste ?'),
          content: const Text(
            'Tous les ingrédients de la liste de courses seront supprimés.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Vider'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      shoppingStore.clearAll();
    }
  }
}

enum _ShoppingAction { addCheckedToFridge, clearChecked, clearAll }

class _PurchasedDraft {
  const _PurchasedDraft({
    required this.item,
    required this.category,
    required this.expiryDate,
  });

  final ShoppingItem item;
  final FoodCategory category;
  final DateTime expiryDate;

  _PurchasedDraft copyWith({FoodCategory? category, DateTime? expiryDate}) {
    return _PurchasedDraft(
      item: item,
      category: category ?? this.category,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }

  FoodItem toFoodItem(String suffix) {
    final unit = _unitForFood(item.unit);

    return FoodItem(
      id: 'shopping_${item.id}_$suffix',
      name: item.name,
      emoji: FoodCategoryHelper.emoji(category),
      expiryDate: expiryDate,
      category: category,
      quantity: MeasurementHelper.logicalQuantity(item.amount, unit),
      amount: item.amount,
      unit: unit,
    );
  }

  static String _unitForFood(String unit) {
    return unit
        .trim()
        .toLowerCase()
        .replaceAll('unités', 'unité')
        .replaceAll('tranches', 'tranche');
  }
}

class _AddCheckedToFridgeSheet extends StatefulWidget {
  const _AddCheckedToFridgeSheet({required this.items});

  final List<ShoppingItem> items;

  @override
  State<_AddCheckedToFridgeSheet> createState() =>
      _AddCheckedToFridgeSheetState();
}

class _AddCheckedToFridgeSheetState extends State<_AddCheckedToFridgeSheet> {
  late List<_PurchasedDraft> _drafts;

  @override
  void initState() {
    super.initState();

    final today = DateTime.now();
    final defaultExpiryDate = DateTime(
      today.year,
      today.month,
      today.day,
    ).add(const Duration(days: 7));

    _drafts = [
      for (final item in widget.items)
        _PurchasedDraft(
          item: item,
          category: _guessCategory(item.name),
          expiryDate: defaultExpiryDate,
        ),
    ];
  }

  Future<void> _pickExpiryDate(int index) async {
    final draft = _drafts[index];
    final picked = await showDatePicker(
      context: context,
      initialDate: draft.expiryDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      helpText: 'Date d’expiration',
      cancelText: 'Annuler',
      confirmText: 'OK',
    );

    if (picked == null) return;

    setState(() {
      _drafts[index] = draft.copyWith(
        expiryDate: DateTime(picked.year, picked.month, picked.day),
      );
    });
  }

  void _updateCategory(int index, FoodCategory category) {
    setState(() {
      _drafts[index] = _drafts[index].copyWith(category: category);
    });
  }

  void _confirm() {
    Navigator.pop(context, _drafts);
  }

  static FoodCategory _guessCategory(String name) {
    return FoodCategoryHelper.suggestForName(name);
  }

  String _formatDate(DateTime date) {
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
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Ajouter au frigo',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vérifie la catégorie et la date avant d’ajouter tes achats au frigo.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ..._drafts.asMap().entries.map((entry) {
                      final index = entry.key;
                      final draft = entry.value;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PurchasedDraftCard(
                          draft: draft,
                          formattedDate: _formatDate(draft.expiryDate),
                          onCategoryChanged: (category) {
                            if (category != null) {
                              _updateCategory(index, category);
                            }
                          },
                          onPickDate: () => _pickExpiryDate(index),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _confirm,
                      icon: const Icon(Icons.kitchen_rounded),
                      label: const Text('Ajouter'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
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
}

class _PurchasedDraftCard extends StatelessWidget {
  const _PurchasedDraftCard({
    required this.draft,
    required this.formattedDate,
    required this.onCategoryChanged,
    required this.onPickDate,
  });

  final _PurchasedDraft draft;
  final String formattedDate;
  final ValueChanged<FoodCategory?> onCategoryChanged;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  FoodCategoryHelper.icon(draft.category),
                  size: 24,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.item.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      draft.item.amountLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<FoodCategory>(
            initialValue: draft.category,
            decoration: InputDecoration(
              labelText: 'Catégorie',
              filled: true,
              fillColor: colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            items: FoodCategory.values
                .map(
                  (category) => DropdownMenuItem<FoodCategory>(
                    value: category,
                    child: Text(FoodCategoryHelper.label(category)),
                  ),
                )
                .toList(),
            onChanged: onCategoryChanged,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onPickDate,
            icon: const Icon(Icons.event_outlined),
            label: Text('DLC estimée : $formattedDate'),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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

class _ShoppingListHeader extends StatelessWidget {
  const _ShoppingListHeader({
    required this.totalCount,
    required this.checkedCount,
    required this.onAddCheckedToFridge,
    required this.onClearChecked,
    required this.onClearAll,
  });

  final int totalCount;
  final int checkedCount;
  final VoidCallback? onAddCheckedToFridge;
  final VoidCallback? onClearChecked;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$totalCount ingrédient${totalCount > 1 ? 's' : ''} à acheter',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$checkedCount déjà coché${checkedCount > 1 ? 's' : ''}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAddCheckedToFridge,
            icon: const Icon(Icons.kitchen_rounded),
            label: const Text('Ajouter cochés au frigo'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onClearChecked,
                  icon: const Icon(Icons.checklist_rtl_rounded),
                  label: const Text('Supprimer cochés'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onClearAll,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Tout vider'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShoppingItemCard extends StatelessWidget {
  const _ShoppingItemCard({
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  final ShoppingItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Checkbox(value: item.isChecked, onChanged: (_) => onToggle()),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          decoration: item.isChecked
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.amountLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: colorScheme.error,
                  ),
                  tooltip: 'Supprimer',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyShoppingListView extends StatelessWidget {
  const _EmptyShoppingListView();

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
              Icons.shopping_cart_outlined,
              size: 56,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Ta liste est vide',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ajoute les ingrédients manquants depuis une recette.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
