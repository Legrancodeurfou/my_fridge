import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _nameKey = 'profile_name';
  static const _levelKey = 'profile_cooking_level';
  static const _goalKey = 'profile_goal';
  static const _airfryerKey = 'profile_airfryer';
  static const _ovenKey = 'profile_oven';
  static const _microwaveKey = 'profile_microwave';
  static const _thermomixKey = 'profile_thermomix';

  final _nameController = TextEditingController();

  String _cookingLevel = 'Intermédiaire';
  String _goal = 'Réduire le gaspillage';

  bool _hasAirfryer = false;
  bool _hasOven = true;
  bool _hasMicrowave = true;
  bool _hasThermomix = false;

  bool _isLoading = true;

  final List<String> _levels = [
    'Débutant',
    'Intermédiaire',
    'Confirmé',
  ];

  final List<String> _goals = [
    'Économiser',
    'Manger plus sain',
    'Réduire le gaspillage',
    'Gagner du temps',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _nameController.addListener(_saveName);
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_saveName)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();

    _nameController.text = prefs.getString(_nameKey) ?? 'Esteban';

    setState(() {
      _cookingLevel = prefs.getString(_levelKey) ?? 'Intermédiaire';
      _goal = prefs.getString(_goalKey) ?? 'Réduire le gaspillage';
      _hasAirfryer = prefs.getBool(_airfryerKey) ?? false;
      _hasOven = prefs.getBool(_ovenKey) ?? true;
      _hasMicrowave = prefs.getBool(_microwaveKey) ?? true;
      _hasThermomix = prefs.getBool(_thermomixKey) ?? false;
      _isLoading = false;
    });
  }

  Future<void> _saveName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, _nameController.text.trim());
  }

  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
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

          _SectionTitle(title: 'Préférences'),
          const SizedBox(height: 8),

          _DropdownCard(
            icon: Icons.restaurant_menu_rounded,
            title: 'Niveau de cuisine',
            value: _cookingLevel,
            items: _levels,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _cookingLevel = value);
              _saveString(_levelKey, value);
            },
          ),

          const SizedBox(height: 12),

          _DropdownCard(
            icon: Icons.flag_rounded,
            title: 'Objectif principal',
            value: _goal,
            items: _goals,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _goal = value);
              _saveString(_goalKey, value);
            },
          ),

          const SizedBox(height: 24),

          _SectionTitle(title: 'Équipements disponibles'),
          const SizedBox(height: 8),

          _SwitchCard(
            icon: Icons.air_rounded,
            title: 'Airfryer',
            value: _hasAirfryer,
            onChanged: (value) {
              setState(() => _hasAirfryer = value);
              _saveBool(_airfryerKey, value);
            },
          ),

          const SizedBox(height: 10),

          _SwitchCard(
            icon: Icons.local_fire_department_rounded,
            title: 'Four',
            value: _hasOven,
            onChanged: (value) {
              setState(() => _hasOven = value);
              _saveBool(_ovenKey, value);
            },
          ),

          const SizedBox(height: 10),

          _SwitchCard(
            icon: Icons.microwave_rounded,
            title: 'Micro-ondes',
            value: _hasMicrowave,
            onChanged: (value) {
              setState(() => _hasMicrowave = value);
              _saveBool(_microwaveKey, value);
            },
          ),

          const SizedBox(height: 10),

          _SwitchCard(
            icon: Icons.blender_rounded,
            title: 'Thermomix',
            value: _hasThermomix,
            onChanged: (value) {
              setState(() => _hasThermomix = value);
              _saveBool(_thermomixKey, value);
            },
          ),

          const SizedBox(height: 24),

          _InfoCard(
            icon: Icons.info_outline_rounded,
            title: 'Version MVP',
            subtitle: 'My Fridge MVP v0.1',
          ),
        ],
      ),
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
            child: Icon(
              Icons.person_rounded,
              size: 52,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: nameController,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              hintText: 'Ton prénom',
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
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
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _DropdownCard extends StatelessWidget {
  const _DropdownCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _CardContainer(
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              borderRadius: BorderRadius.circular(14),
              items: items
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(item),
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
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

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
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
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
      child: child,
    );
  }
}