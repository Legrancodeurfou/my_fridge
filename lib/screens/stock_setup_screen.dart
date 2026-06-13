import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/fridge_store.dart';
import '../data/profile_store.dart';
import '../models/food.dart';
import '../models/stock_setup_defaults.dart';

class StockSetupScreen extends StatefulWidget {
  const StockSetupScreen({
    super.key,
    required this.store,
    required this.profileStore,
    required this.onOpenScan,
  });

  final FridgeStore store;
  final ProfileStore profileStore;
  final VoidCallback onOpenScan;

  @override
  State<StockSetupScreen> createState() => _StockSetupScreenState();
}

class _StockSetupScreenState extends State<StockSetupScreen> {
  StorageLocation? _selectedLocation;

  void _openScan() {
    Navigator.pop(context);
    widget.onOpenScan();
  }

  void _showPhotoComingSoon() {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Cette option arrivera plus tard. Pour l’instant, utilise l’ajout '
          'rapide ou le scan ticket.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _selectedLocation == null
            ? null
            : IconButton(
                onPressed: () => setState(() => _selectedLocation = null),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Retour aux zones',
              ),
        title: const Text('Mise en route du stock'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final location = _selectedLocation;
          if (location != null) {
            return _QuickZoneAddView(
              key: ValueKey(location),
              store: widget.store,
              location: location,
              onChooseAnotherZone: () {
                setState(() => _selectedLocation = null);
              },
              onFinish: () => Navigator.pop(context),
            );
          }

          return _StockSetupOverview(
            foods: widget.store.foods,
            profileStore: widget.profileStore,
            onLocationSelected: (value) {
              setState(() => _selectedLocation = value);
            },
            onOpenScan: _openScan,
            onPhotoTap: _showPhotoComingSoon,
          );
        },
      ),
    );
  }
}

class _StockSetupOverview extends StatelessWidget {
  const _StockSetupOverview({
    required this.foods,
    required this.profileStore,
    required this.onLocationSelected,
    required this.onOpenScan,
    required this.onPhotoTap,
  });

  final List<FoodItem> foods;
  final ProfileStore profileStore;
  final ValueChanged<StorageLocation> onLocationSelected;
  final VoidCallback onOpenScan;
  final VoidCallback onPhotoTap;

  int _countFor(StorageLocation location) {
    return foods.where((food) => food.storageLocation == location).length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const locations = [
      StorageLocation.fridge,
      StorageLocation.pantry,
      StorageLocation.freezer,
      StorageLocation.spices,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        _ProfileNameSetupCard(store: profileStore),
        const SizedBox(height: 24),
        Text(
          'Ajoute ce que tu as déjà chez toi',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ton stock aide l’app à proposer de meilleures recettes et à '
          'repérer ce qu’il faut consommer en priorité.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth >= 620
                ? (constraints.maxWidth - 16) / 2
                : constraints.maxWidth;

            return Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                for (final location in locations)
                  SizedBox(
                    width: cardWidth,
                    child: _SetupZoneCard(
                      location: location,
                      count: _countFor(location),
                      onTap: () => onLocationSelected(location),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        Text(
          'Autres façons de commencer',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        _SetupActionCard(
          icon: Icons.receipt_long_outlined,
          title: 'Scanner un ticket',
          subtitle:
              'Idéal si tu viens de faire des courses. Tu valideras chaque '
              'produit avant l’ajout.',
          actionLabel: 'Ouvrir le scan',
          onTap: onOpenScan,
        ),
        const SizedBox(height: 12),
        _SetupActionCard(
          icon: Icons.photo_camera_back_outlined,
          title: 'Photo du frigo',
          subtitle:
              'Une future option pour reconnaître rapidement ce que tu as '
              'déjà chez toi.',
          actionLabel: 'Bientôt',
          onTap: onPhotoTap,
          isComingSoon: true,
        ),
      ],
    );
  }
}

class _ProfileNameSetupCard extends StatefulWidget {
  const _ProfileNameSetupCard({required this.store});

  final ProfileStore store;

  @override
  State<_ProfileNameSetupCard> createState() => _ProfileNameSetupCardState();
}

class _ProfileNameSetupCardState extends State<_ProfileNameSetupCard> {
  late final TextEditingController _controller;
  String? _errorText;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.store.profile.name);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() {
        _errorText = 'Tu peux remplir ce champ maintenant ou plus tard.';
        _saved = false;
      });
      return;
    }

    final saved = await widget.store.updateName(value);
    if (!mounted || !saved) return;
    setState(() {
      _errorText = null;
      _saved = true;
    });
    FocusScope.of(context).unfocus();
  }

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
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comment veux-tu qu’on t’appelle ?',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Facultatif : tu pourras aussi le modifier plus tard dans Profil.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_errorText != null || _saved) {
                setState(() {
                  _errorText = null;
                  _saved = false;
                });
              }
            },
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: 'Prénom ou nom',
              hintText: 'Ex. Camille',
              errorText: _errorText,
              prefixIcon: const Icon(Icons.person_outline_rounded),
              suffixIcon: _saved
                  ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _save,
              child: const Text('Enregistrer'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupZoneCard extends StatelessWidget {
  const _SetupZoneCard({
    required this.location,
    required this.count,
    required this.onTap,
  });

  final StorageLocation location;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.07),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  StorageLocationHelper.icon(location),
                  color: colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      StorageLocationHelper.label(location),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$count aliment${count > 1 ? 's' : ''}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: onTap,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Ajouter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupActionCard extends StatelessWidget {
  const _SetupActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
    this.isComingSoon = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;
  final bool isComingSoon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isComingSoon
                      ? colorScheme.surfaceContainerHighest
                      : colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: isComingSoon
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.primary,
                ),
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
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Chip(
                label: Text(actionLabel),
                avatar: Icon(
                  isComingSoon
                      ? Icons.schedule_rounded
                      : Icons.arrow_forward_rounded,
                  size: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickZoneAddView extends StatefulWidget {
  const _QuickZoneAddView({
    super.key,
    required this.store,
    required this.location,
    required this.onChooseAnotherZone,
    required this.onFinish,
  });

  final FridgeStore store;
  final StorageLocation location;
  final VoidCallback onChooseAnotherZone;
  final VoidCallback onFinish;

  @override
  State<_QuickZoneAddView> createState() => _QuickZoneAddViewState();
}

class _QuickZoneAddViewState extends State<_QuickZoneAddView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController(text: '1');
  final _nameFocusNode = FocusNode();
  final List<FoodItem> _recentlyAdded = [];

  String _unit = 'unité';
  FoodCategory _category = FoodCategory.other;
  late DateTime _expiryDate;
  bool _unitWasEdited = false;
  bool _categoryWasEdited = false;
  bool _amountWasEdited = false;

  @override
  void initState() {
    super.initState();
    _expiryDate = StockSetupDefaults.estimatedExpiry(widget.location);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  int get _zoneCount => widget.store.foods
      .where((food) => food.storageLocation == widget.location)
      .length;

  void _applyNameSuggestions(String name) {
    setState(() {
      if (!_categoryWasEdited) {
        _category = FoodCategoryHelper.suggestForName(name);
      }
      if (!_unitWasEdited) {
        final suggestedUnit = FoodUnitHelper.suggestForName(
          name,
          useCommonDefault: true,
        );
        if (suggestedUnit != _unit) {
          _unit = suggestedUnit;
          if (!_amountWasEdited) {
            _amountController.text = MeasurementHelper.inputValue(
              FoodUnitHelper.defaultAmountFor(suggestedUnit),
            );
          }
        }
      }
    });
  }

  double? _parseAmount() {
    return double.tryParse(_amountController.text.trim().replaceAll(',', '.'));
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: 'Modifier la date estimée',
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );

    if (picked == null || !mounted) return;
    setState(() {
      _expiryDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  void _addAndContinue() {
    if (_formKey.currentState?.validate() != true) return;

    final amount = _parseAmount();
    if (amount == null || amount <= 0) return;

    final food = StockSetupDefaults.createFood(
      id: 'setup_${DateTime.now().microsecondsSinceEpoch}',
      name: _nameController.text.trim(),
      amount: amount,
      unit: _unit,
      category: _category,
      storageLocation: widget.location,
      expiryDate: _expiryDate,
    );

    widget.store.addFood(food);
    setState(() {
      _recentlyAdded.insert(0, food);
      _nameController.clear();
      _amountController.text = '1';
      _unit = 'unité';
      _category = FoodCategory.other;
      _expiryDate = StockSetupDefaults.estimatedExpiry(widget.location);
      _unitWasEdited = false;
      _categoryWasEdited = false;
      _amountWasEdited = false;
    });

    _nameFocusNode.requestFocus();

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text('${food.name} ajouté à ${_locationDestinationLabel()}'),
      ),
    );
  }

  String _locationDestinationLabel() {
    return switch (widget.location) {
      StorageLocation.fridge => 'ton frigo',
      StorageLocation.pantry => 'ton placard',
      StorageLocation.freezer => 'ton congélateur',
      StorageLocation.spices => 'tes épices',
    };
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                StorageLocationHelper.icon(widget.location),
                color: colorScheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ajouter dans ${StorageLocationHelper.label(widget.location)}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$_zoneCount aliment${_zoneCount > 1 ? 's' : ''} '
                    'actuellement dans cette zone',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  onChanged: _applyNameSuggestions,
                  decoration: const InputDecoration(
                    labelText: 'Nom du produit',
                    hintText: 'Ex. Lait, Riz, Poivre…',
                    prefixIcon: Icon(Icons.label_outline_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Indique un nom de produit';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final amountField = TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                      ],
                      onChanged: (_) => _amountWasEdited = true,
                      decoration: const InputDecoration(
                        labelText: 'Quantité',
                        prefixIcon: Icon(Icons.numbers_rounded),
                      ),
                      validator: (value) {
                        final amount = double.tryParse(
                          (value ?? '').replaceAll(',', '.'),
                        );
                        if (amount == null || amount <= 0) {
                          return 'Quantité invalide';
                        }
                        return null;
                      },
                    );
                    final unitField = DropdownButtonFormField<String>(
                      key: ValueKey(_unit),
                      initialValue: _unit,
                      decoration: const InputDecoration(labelText: 'Unité'),
                      items: MeasurementHelper.units.map((unit) {
                        return DropdownMenuItem(value: unit, child: Text(unit));
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        final currentAmount = _parseAmount() ?? 1;
                        setState(() {
                          _amountController.text = MeasurementHelper.inputValue(
                            MeasurementHelper.amountAfterUnitChange(
                              currentAmount,
                              fromUnit: _unit,
                              toUnit: value,
                            ),
                          );
                          _unit = value;
                          _unitWasEdited = true;
                          _amountWasEdited = true;
                        });
                      },
                    );

                    if (constraints.maxWidth < 420) {
                      return Column(
                        children: [
                          amountField,
                          const SizedBox(height: 14),
                          unitField,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: amountField),
                        const SizedBox(width: 12),
                        Expanded(child: unitField),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<FoodCategory>(
                  key: ValueKey(_category),
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Catégorie proposée',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: FoodCategory.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Row(
                        children: [
                          Icon(FoodCategoryHelper.icon(category), size: 19),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              FoodCategoryHelper.label(category),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _category = value;
                      _categoryWasEdited = true;
                    });
                  },
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _pickExpiryDate,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    'Date estimée : ${_formatDate(_expiryDate)} · Modifier',
                  ),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _addAndContinue,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Ajouter et continuer'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_recentlyAdded.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Ajoutés pendant cette session',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ..._recentlyAdded
              .take(6)
              .map(
                (food) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RecentlyAddedTile(food: food),
                ),
              ),
        ],
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: widget.onChooseAnotherZone,
          icon: const Icon(Icons.grid_view_rounded),
          label: const Text('Choisir une autre zone'),
        ),
        const SizedBox(height: 10),
        FilledButton(onPressed: widget.onFinish, child: const Text('Terminer')),
      ],
    );
  }
}

class _RecentlyAddedTile extends StatelessWidget {
  const _RecentlyAddedTile({required this.food});

  final FoodItem food;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              FoodCategoryHelper.icon(food.category),
              size: 21,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              food.name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            food.amountLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
