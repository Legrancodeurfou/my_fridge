import 'package:flutter/material.dart';

import '../data/shopping_list_store.dart';
import '../models/shopping_item.dart';

class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key, required this.store});

  final ShoppingListStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final items = store.items;
        final checkedCount = items.where((item) => item.isChecked).length;

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          appBar: AppBar(
            title: const Text('Liste de courses'),
            centerTitle: false,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
            actions: [
              if (items.isNotEmpty)
                PopupMenuButton<_ShoppingAction>(
                  onSelected: (action) {
                    if (action == _ShoppingAction.clearChecked) {
                      store.clearChecked();
                    } else if (action == _ShoppingAction.clearAll) {
                      _confirmClearAll(context);
                    }
                  },
                  itemBuilder: (context) => [
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
                        onClearChecked: checkedCount == 0 ? null : store.clearChecked,
                        onClearAll: () => _confirmClearAll(context),
                      );
                    }

                    final item = items[index - 1];
                    return _ShoppingItemCard(
                      item: item,
                      onToggle: () => store.toggleItem(item.id),
                      onDelete: () => store.deleteItem(item.id),
                    );
                  },
                ),
        );
      },
    );
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Vider la liste ?'),
          content: const Text('Tous les ingrédients de la liste de courses seront supprimés.'),
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
      store.clearAll();
    }
  }
}

enum _ShoppingAction { clearChecked, clearAll }

class _ShoppingListHeader extends StatelessWidget {
  const _ShoppingListHeader({
    required this.totalCount,
    required this.checkedCount,
    required this.onClearChecked,
    required this.onClearAll,
  });

  final int totalCount;
  final int checkedCount;
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
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$totalCount ingrédient${totalCount > 1 ? 's' : ''} à acheter',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '$checkedCount déjà coché${checkedCount > 1 ? 's' : ''}',
            style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
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
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.45)),
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
                Checkbox(
                  value: item.isChecked,
                  onChanged: (_) => onToggle(),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration: item.isChecked ? TextDecoration.lineThrough : null,
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
                  icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
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
