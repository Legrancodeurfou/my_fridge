import 'package:flutter/material.dart';

import '../data/fridge_store.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    required this.store,
    required this.onNavigateToFridge,
  });

  final FridgeStore store;
  final VoidCallback onNavigateToFridge;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _isScanning = false;

  Future<void> _simulateTicketScan() async {
    if (_isScanning) return;

    setState(() => _isScanning = true);

    await Future<void>.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    widget.store.addTicketScanResults();
    setState(() => _isScanning = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: const Text('4 aliments ajoutés depuis le ticket !'),
      ),
    );

    widget.onNavigateToFridge();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Ticket'),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.camera_alt,
                  size: 90,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Scanne ton ticket de caisse',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Prends une photo de ton ticket pour ajouter automatiquement tes produits dans ton frigo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? null : _simulateTicketScan,
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Prendre une photo'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isScanning ? null : () {},
                    icon: const Icon(Icons.edit),
                    label: const Text('Ajouter manuellement'),
                  ),
                ),
              ],
            ),
          ),
          if (_isScanning) const _ScanLoadingOverlay(),
        ],
      ),
    );
  }
}

class _ScanLoadingOverlay extends StatelessWidget {
  const _ScanLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colorScheme.surface.withValues(alpha: 0.92),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              'Analyse du ticket...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
