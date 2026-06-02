import 'package:flutter/material.dart';

import '../data/profile_store.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.store,
    required this.onResetDemoData,
  });

  final ProfileStore store;
  final Future<void> Function() onResetDemoData;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _nameController;

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
      listenable: widget.store,
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
              _ResetDataCard(onReset: _confirmResetDemoData),
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

class _ResetDataCard extends StatelessWidget {
  const _ResetDataCard({required this.onReset});

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
                onPressed: onReset,
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
