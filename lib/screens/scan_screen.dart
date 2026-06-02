import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

import '../data/fridge_store.dart';
import '../data/scan_history_store.dart';
import '../models/detected_product_draft.dart';
import '../models/food.dart';
import '../models/scan_history_item.dart';
import '../services/ticket_analysis_service.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    required this.store,
    required this.historyStore,
    required this.onNavigateToFridge,
  });

  final FridgeStore store;
  final ScanHistoryStore historyStore;
  final VoidCallback onNavigateToFridge;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _imagePicker = ImagePicker();
  final _ticketAnalysis = const TicketAnalysisService();

  Uint8List? _pickedImageBytes;
  bool _isScanning = false;

  Future<void> _showImageSourceSheet() async {
    if (_isScanning) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
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
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Choisir une source',
                    style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.photo_camera_outlined),
                    title: const Text('Prendre une photo'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () =>
                        Navigator.pop(sheetContext, ImageSource.camera),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.photo_library_outlined),
                    title: const Text('Choisir dans la galerie'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () =>
                        Navigator.pop(sheetContext, ImageSource.gallery),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (source == null || !mounted) return;
    await _pickImage(source);
  }

Future<void> _pickImage(ImageSource source) async {
  try {
    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (!mounted) return;
      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes;

      if (bytes == null) {
        throw Exception('Image introuvable');
      }

      setState(() => _pickedImageBytes = bytes);
      return;
    }

    final image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (!mounted) return;
    if (image == null) return;

    final bytes = await image.readAsBytes();

    if (!mounted) return;

    setState(() => _pickedImageBytes = bytes);
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Erreur : $e'),
      ),
    );
  }
}

  Future<void> _analyzeTicket() async {
    if (_isScanning || _pickedImageBytes == null) return;

    setState(() => _isScanning = true);

    final detectedDrafts =
        await _ticketAnalysis.analyzeTicket(_pickedImageBytes!);

    if (!mounted) return;

    setState(() => _isScanning = false);

    await _showValidationSheet(detectedDrafts);
  }

  Future<void> _showManualAddSheet() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: _ManualFoodFormSheet(
            onSave: (food) {
              widget.store.addFood(food);
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

              widget.onNavigateToFridge();
            },
          ),
        );
      },
    );
  }

  Future<void> _showValidationSheet(List<DetectedProductDraft> detectedDrafts) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) {
        return _ScanValidationSheet(
          detectedDrafts: detectedDrafts,
          onCancel: () => Navigator.pop(sheetContext),
          onValidate: (selectedFoods) {
            widget.store.addFoods(selectedFoods);
            widget.historyStore.addScan(
              detectedCount: detectedDrafts.length,
              validatedFoods: selectedFoods,
            );
            Navigator.pop(sheetContext);

            final count = selectedFoods.length;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                content: Text(
                  count == 1
                      ? '1 aliment ajouté au frigo'
                      : '$count aliments ajoutés au frigo',
                ),
              ),
            );

            widget.onNavigateToFridge();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasPreview = _pickedImageBytes != null;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Scan Ticket'),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surfaceContainerLowest,
        actions: [
          if (_pickedImageBytes != null)
            IconButton(
              tooltip: 'Fermer l’aperçu',
              icon: const Icon(Icons.close_rounded),
              onPressed: _isScanning
                  ? null
                  : () {
                      setState(() {
                        _pickedImageBytes = null;
                      });
                    },
            ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: hasPreview
                ? _buildPreviewContent(context)
                : _buildInitialContent(context),
          ),
          if (_isScanning) const _ScanLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildInitialContent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Icon(
            Icons.camera_alt_rounded,
            size: 90,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Scanne ton ticket de caisse',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Prends une photo de ton ticket pour ajouter automatiquement tes produits dans ton frigo.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _isScanning ? null : _showImageSourceSheet,
            icon: const Icon(Icons.photo_camera_rounded),
            label: const Text('Prendre une photo'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isScanning ? null : _showManualAddSheet,
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Ajouter manuellement'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 32),
          _RecentScansSection(historyStore: widget.historyStore),
        ],
      ),
    );
  }

  Widget _buildPreviewContent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final imageBytes = _pickedImageBytes!;
    final previewMaxHeight = MediaQuery.sizeOf(context).height * 0.42;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Aperçu du ticket',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Vérifie que le ticket est lisible avant l’analyse.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _TicketPreviewCard(
            imageBytes: imageBytes,
            maxHeight: previewMaxHeight,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isScanning ? null : _analyzeTicket,
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Analyser le ticket'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isScanning ? null : _showImageSourceSheet,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Reprendre une photo'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
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

/// Carte d’aperçu du ticket (style aligné sur les cartes du frigo).

class _RecentScansSection extends StatelessWidget {
  const _RecentScansSection({required this.historyStore});

  final ScanHistoryStore historyStore;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: historyStore,
      builder: (context, _) {
        final scans = historyStore.recent(limit: 3);
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Derniers scans',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (historyStore.items.isNotEmpty)
                  TextButton(
                    onPressed: () => _confirmClearHistory(context),
                    child: const Text('Effacer'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (scans.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Aucun scan pour l’instant. Les tickets validés apparaîtront ici.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...scans.map(
                (scan) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ScanHistoryCard(
                    scan: scan,
                    onTap: () => _showScanDetails(context, scan),
                    onDelete: () => historyStore.deleteScan(scan.id),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _confirmClearHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Effacer l’historique ?'),
          content: const Text('Tous les scans enregistrés seront supprimés.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Effacer'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) historyStore.clearAll();
  }

  void _showScanDetails(BuildContext context, ScanHistoryItem scan) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ScanHistoryDetailSheet(scan: scan),
    );
  }
}

class _ScanHistoryCard extends StatelessWidget {
  const _ScanHistoryCard({
    required this.scan,
    required this.onTap,
    required this.onDelete,
  });

  final ScanHistoryItem scan;
  final VoidCallback onTap;
  final VoidCallback onDelete;

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
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
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
                  color: colorScheme.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.receipt_long_rounded, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatScanDate(scan.scannedAt),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${scan.validatedCount}/${scan.detectedCount} produit${scan.detectedCount > 1 ? 's' : ''} ajouté${scan.validatedCount > 1 ? 's' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      scan.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
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
    );
  }
}

class _ScanHistoryDetailSheet extends StatelessWidget {
  const _ScanHistoryDetailSheet({required this.scan});

  final ScanHistoryItem scan;

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
                'Détail du scan',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatScanDate(scan.scannedAt),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              ...scan.products.map(
                (product) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        product.amountLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
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

String _formatScanDate(DateTime date) {
  final now = DateTime.now();
  final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
  final day = isToday
      ? 'Aujourd’hui'
      : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day à $hour:$minute';
}

class _TicketPreviewCard extends StatelessWidget {
  const _TicketPreviewCard({
    required this.imageBytes,
    required this.maxHeight,
  });

  final Uint8List imageBytes;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: colorScheme.surface,
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
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Image.memory(
          imageBytes,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

class _ScanValidationSheet extends StatefulWidget {
  const _ScanValidationSheet({
    required this.detectedDrafts,
    required this.onCancel,
    required this.onValidate,
  });

  final List<DetectedProductDraft> detectedDrafts;
  final VoidCallback onCancel;
  final void Function(List<FoodItem> selectedFoods) onValidate;

  @override
  State<_ScanValidationSheet> createState() => _ScanValidationSheetState();
}

class _ScanValidationSheetState extends State<_ScanValidationSheet> {
  late List<DetectedProductDraft> _items;

  @override
  void initState() {
    super.initState();
    _items = List<DetectedProductDraft>.from(widget.detectedDrafts);
  }

  void _removeItem(String id) {
    setState(() => _items.removeWhere((draft) => draft.id == id));
  }

  void _incrementQuantity(String id) {
    setState(() {
      _items = _items.map((draft) {
        if (draft.id != id) return draft;
        final step = MeasurementHelper.stepFor(draft.unit);
        final nextAmount = draft.amount + step;
        return draft.copyWith(amount: nextAmount);
      }).toList();
    });
  }

  void _decrementQuantity(String id) {
    setState(() {
      _items = _items.map((draft) {
        if (draft.id != id) return draft;
        final step = MeasurementHelper.stepFor(draft.unit);
        final nextAmount = draft.amount - step;
        if (nextAmount <= 0) return draft;
        return draft.copyWith(amount: nextAmount);
      }).toList();
    });
  }

  List<FoodItem> _foodsForFridge() {
    return _items.map((draft) => draft.toFoodItem()).toList();
  }

  int get _totalLines => _items.length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canValidate = _items.isNotEmpty;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.receipt_long_rounded,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Produits détectés',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Vérifie la liste avant de l’ajouter au frigo.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _items.isEmpty
                        ? 'Aucun produit sélectionné'
                        : '${_items.length} produit${_items.length > 1 ? 's' : ''} · '
                            '$_totalLines ligne${_totalLines > 1 ? 's' : ''}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _items.length,
                separatorBuilder: (context, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final draft = _items[index];
                  return _DetectedProductTile(
                    draft: draft,
                    onIncrement: () => _incrementQuantity(draft.id),
                    onDecrement: () => _decrementQuantity(draft.id),
                    onRemove: () => _removeItem(draft.id),
                  );
                },
              ),
            ),
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  'Aucun produit sélectionné. Annule ou relance un scan.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onCancel,
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
                    child: FilledButton(
                      onPressed: canValidate
                          ? () => widget.onValidate(_foodsForFridge())
                          : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Valider'),
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

class _DetectedProductTile extends StatelessWidget {
  const _DetectedProductTile({
    required this.draft,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final DetectedProductDraft draft;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final expiryLabel =
        ExpiryHelper.labelFor(draft.estimatedExpirationDate);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackControls = constraints.maxWidth < 340;

          final nameColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                draft.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                expiryLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );

          final controlsRow = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QuantityStepper(
                amountLabel: draft.amountLabel,
                canDecrement: draft.amount > MeasurementHelper.stepFor(draft.unit),
                onDecrement: onDecrement,
                onIncrement: onIncrement,
              ),
              IconButton(
                onPressed: onRemove,
                icon: Icon(Icons.close_rounded, color: colorScheme.error),
                tooltip: 'Retirer',
                visualDensity: VisualDensity.compact,
              ),
            ],
          );

          if (stackControls) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(draft.emoji, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 12),
                    Expanded(child: nameColumn),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: controlsRow,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(draft.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(child: nameColumn),
              controlsRow,
            ],
          );
        },
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
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

class _ManualFoodFormSheet extends StatefulWidget {
  const _ManualFoodFormSheet({required this.onSave});

  final void Function(FoodItem food) onSave;

  @override
  State<_ManualFoodFormSheet> createState() => _ManualFoodFormSheetState();
}

class _ManualFoodFormSheetState extends State<_ManualFoodFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  double _amount = 1;
  String _unit = 'unité';
  FoodCategory _category = FoodCategory.other;
  late DateTime _expiryDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    final now = DateTime.now();
    _expiryDate = DateTime(now.year, now.month, now.day).add(
      const Duration(days: 7),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _incrementAmount() {
    setState(() => _amount += MeasurementHelper.stepFor(_unit));
  }

  void _decrementAmount() {
    final nextAmount = _amount - MeasurementHelper.stepFor(_unit);
    if (nextAmount <= 0) return;
    setState(() => _amount = nextAmount);
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 730)),
    );

    if (picked == null || !mounted) return;
    setState(() => _expiryDate = DateTime(picked.year, picked.month, picked.day));
  }

  void _save() {
    if (_formKey.currentState?.validate() != true) return;

    final name = _nameController.text.trim();
    final food = FoodItem(
      id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.edit_rounded, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ajouter un produit',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ajoute un aliment sans scanner de ticket.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nom du produit',
                    hintText: 'Ex : Pain, Riz, Poulet...',
                    prefixIcon: Icon(Icons.kitchen_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Entre un nom de produit';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<FoodCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Catégorie',
                    prefixIcon: Icon(Icons.category_rounded),
                  ),
                  items: FoodCategory.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(FoodCategoryHelper.label(category)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _category = value);
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _ManualAmountStepper(
                        amountLabel: MeasurementHelper.label(_amount, _unit),
                        canDecrement: _amount > MeasurementHelper.stepFor(_unit),
                        onDecrement: _decrementAmount,
                        onIncrement: _incrementAmount,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 130,
                      child: DropdownButtonFormField<String>(
                        initialValue: _unit,
                        decoration: const InputDecoration(labelText: 'Unité'),
                        items: MeasurementHelper.units.map((unit) {
                          return DropdownMenuItem(
                            value: unit,
                            child: Text(unit),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _unit = value;
                            if (_amount <= 0) _amount = MeasurementHelper.stepFor(_unit);
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _pickExpiryDate,
                  icon: const Icon(Icons.event_rounded),
                  label: Text('DLC estimée : ${ExpiryHelper.labelFor(_expiryDate)}'),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
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
                        onPressed: _save,
                        icon: const Icon(Icons.add_rounded),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ManualAmountStepper extends StatelessWidget {
  const _ManualAmountStepper({
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: canDecrement ? onDecrement : null,
            icon: const Icon(Icons.remove_rounded),
            tooltip: 'Diminuer',
          ),
          Expanded(
            child: Text(
              amountLabel,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.primary,
              ),
            ),
          ),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Augmenter',
          ),
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
