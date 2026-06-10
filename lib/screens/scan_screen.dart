import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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
  static const _androidSettingsChannel = MethodChannel(
    'com.myfridge.app/settings',
  );

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
                    style: Theme.of(sheetContext).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Utilise une photo nette où les lignes du ticket sont '
                    'faciles à lire.',
                    textAlign: TextAlign.center,
                    style: Theme.of(sheetContext).textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: const Icon(Icons.photo_camera_outlined),
                      title: const Text('Prendre une photo'),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () =>
                          Navigator.pop(sheetContext, ImageSource.camera),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: const Icon(Icons.photo_library_outlined),
                      title: const Text('Choisir dans la galerie'),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () =>
                          Navigator.pop(sheetContext, ImageSource.gallery),
                    ),
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
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (!mounted) return;
      if (image == null) return;

      final bytes = await image.readAsBytes();

      if (!mounted) return;
      if (bytes.isEmpty) {
        throw Exception('Image vide ou illisible');
      }

      setState(() => _pickedImageBytes = bytes);
    } on PlatformException catch (error) {
      if (!mounted) return;

      debugPrint('Lecture de l’image du ticket impossible : $error');

      if (source == ImageSource.camera &&
          error.code == 'camera_access_denied') {
        await _handleCameraPermissionDenied();
        return;
      }

      _showImageReadError();
    } catch (error) {
      if (!mounted) return;

      debugPrint('Lecture de l’image du ticket impossible : $error');
      _showImageReadError();
    }
  }

  Future<void> _handleCameraPermissionDenied() async {
    var isPermanentlyDenied = false;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final status = await _androidSettingsChannel.invokeMethod<String>(
          'cameraPermissionStatus',
        );
        isPermanentlyDenied = status == 'permanentlyDenied';
      } catch (error) {
        debugPrint('Statut de l’autorisation caméra indisponible : $error');
      }
    }

    if (!mounted) return;

    if (!isPermanentlyDenied) {
      _showScanSnackBar(
        'Accès à la caméra refusé. Tu peux réessayer ou choisir une image '
        'dans la galerie.',
        isError: true,
        actionLabel: 'Galerie',
        onAction: () => _pickImage(ImageSource.gallery),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Autoriser la caméra ?'),
          content: const Text(
            'L’accès à la caméra est désactivé pour My Fridge. Tu peux '
            'l’autoriser dans les réglages Android ou continuer avec une '
            'image de la galerie.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _pickImage(ImageSource.gallery);
              },
              child: const Text('Utiliser la galerie'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await _androidSettingsChannel.invokeMethod<bool>(
                    'openAppSettings',
                  );
                } catch (error) {
                  debugPrint('Ouverture des réglages impossible : $error');
                  if (mounted) {
                    _showScanSnackBar(
                      'Impossible d’ouvrir les réglages automatiquement.',
                      isError: true,
                    );
                  }
                }
              },
              child: const Text('Ouvrir les réglages'),
            ),
          ],
        );
      },
    );
  }

  void _showImageReadError() {
    _showScanSnackBar(
      'Impossible de lire cette image. Essaie une photo plus nette ou '
      'choisis un autre fichier.',
      isError: true,
    );
  }

  Future<void> _analyzeTicket() async {
    if (_isScanning || _pickedImageBytes == null) return;

    setState(() => _isScanning = true);

    try {
      final report = await _ticketAnalysis.analyzeTicketDetailed(
        _pickedImageBytes!,
      );

      if (!mounted) return;

      setState(() => _isScanning = false);

      if (report.errorMessage != null &&
          report.errorMessage!.trim().isNotEmpty) {
        debugPrint(
          'Analyse du ticket passée en mode secours : '
          '${report.errorMessage}',
        );
      }

      if (report.products.isEmpty) {
        _showScanSnackBar(
          'Aucun produit détecté. Vérifie que le ticket est entier, net et '
          'bien éclairé, puis relance l’analyse.',
          isError: true,
        );
        return;
      }

      _showScanSnackBar(
        report.usedFallback
            ? 'Service IA indisponible : résultats de démonstration affichés. '
                  'Vérifie chaque produit avant de valider.'
            : 'Analyse réussie : ${report.products.length} produit(s) '
                  'détecté(s). Vérifie-les avant de les ajouter.',
      );

      await _showValidationSheet(report);
    } catch (error) {
      if (!mounted) return;

      setState(() => _isScanning = false);
      debugPrint('Analyse du ticket impossible : $error');

      _showScanSnackBar(_scanErrorMessage(error), isError: true);
    }
  }

  String _scanErrorMessage(Object error) {
    final detail = error.toString();
    final normalized = detail.toLowerCase();

    if (normalized.contains('network') ||
        normalized.contains('socket') ||
        normalized.contains('connexion') ||
        normalized.contains('failed to fetch')) {
      return 'La connexion réseau est indisponible. Vérifie ta connexion '
          'puis relance l’analyse.';
    }

    if (normalized.contains('gemini') ||
        normalized.contains('indisponible') ||
        normalized.contains('500') ||
        normalized.contains('503')) {
      return 'Le service d’analyse est temporairement indisponible. '
          'Réessaie dans quelques instants.';
    }

    if (normalized.contains('format') ||
        normalized.contains('image') ||
        normalized.contains('invalide')) {
      return 'Le ticket n’a pas pu être lu. Essaie une photo plus nette, '
          'entière et bien éclairée.';
    }

    return 'Impossible d’analyser ce ticket pour le moment. Aucun produit '
        'n’a été ajouté. Réessaie dans quelques instants.';
  }

  void _showScanSnackBar(
    String message, {
    bool isError = false,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (!mounted) return;

    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: isError ? colorScheme.errorContainer : null,
          content: Text(
            message,
            style: isError
                ? TextStyle(color: colorScheme.onErrorContainer)
                : null,
          ),
          action: actionLabel != null && onAction != null
              ? SnackBarAction(label: actionLabel, onPressed: onAction)
              : null,
        ),
      );
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

              _showScanSnackBar('${food.name} a été ajouté au stock.');

              widget.onNavigateToFridge();
            },
          ),
        );
      },
    );
  }

  Future<void> _showValidationSheet(TicketAnalysisReport report) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) {
        return _ScanValidationSheet(
          detectedDrafts: report.products,
          usedFallback: report.usedFallback,
          onCancel: () {
            Navigator.pop(sheetContext);
            _showScanSnackBar(
              'Validation annulée. Aucun produit détecté n’a été ajouté.',
            );
          },
          onValidate: (selectedFoods) {
            widget.store.addFoods(selectedFoods);
            widget.historyStore.addScan(
              detectedCount: report.products.length,
              validatedFoods: selectedFoods,
              source: report.source.name,
              model: report.model,
              errorMessage: report.errorMessage,
            );
            Navigator.pop(sheetContext);

            final count = selectedFoods.length;
            _showScanSnackBar(
              count == 1
                  ? '1 aliment validé et ajouté au stock.'
                  : '$count aliments validés et ajoutés au stock.',
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
        title: const Text('Scanner un ticket'),
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
          Icon(Icons.camera_alt_rounded, size: 90, color: colorScheme.primary),
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
            'Prends une photo ou choisis une image du ticket. Tu pourras '
            'corriger chaque produit avant de l’ajouter au stock.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'À savoir\n',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        TextSpan(
                          text:
                              'L’image du ticket est envoyée à un service '
                              'd’analyse IA pour détecter les produits. Rien '
                              'n’est ajouté au stock sans ta validation.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isScanning ? null : _showImageSourceSheet,
            icon: const Icon(Icons.add_a_photo_rounded),
            label: const Text('Photographier ou choisir un ticket'),
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
            label: const Text('Ajouter un produit sans ticket'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 32),
          _RecentScansSection(historyStore: widget.historyStore),
          const SizedBox(height: 20),
          _AiDiagnosticSection(historyStore: widget.historyStore),
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
            'Vérifie que le ticket est net, entier et bien éclairé avant '
            'l’analyse.',
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
          const SizedBox(height: 12),
          Text(
            'Aucun produit ne sera ajouté automatiquement. Tu confirmeras '
            'la liste après l’analyse.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
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
            icon: const Icon(Icons.image_search_rounded),
            label: const Text('Choisir une autre image'),
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

class _AiDiagnosticSection extends StatelessWidget {
  const _AiDiagnosticSection({required this.historyStore});

  final ScanHistoryStore historyStore;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: historyStore,
      builder: (context, _) {
        final latestScan = historyStore.items.isEmpty
            ? null
            : historyStore.items.first;
        if (latestScan == null) return const SizedBox.shrink();

        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Container(
          padding: const EdgeInsets.all(18),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withValues(
                        alpha: 0.55,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.info_outline_rounded,
                      color: colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Détails du dernier scan',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _DiagnosticRow(label: 'Source', value: latestScan.sourceLabel),
              _DiagnosticRow(label: 'Résultat', value: latestScan.statusLabel),
              _DiagnosticRow(
                label: 'Produits',
                value:
                    '${latestScan.validatedCount}/${latestScan.detectedCount} validés',
              ),
              if (latestScan.model != null &&
                  latestScan.model!.trim().isNotEmpty)
                _DiagnosticRow(label: 'Service', value: latestScan.model!),
              if (latestScan.usedFallback)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Le service d’analyse était indisponible. '
                    'L’app a utilisé le mode démo de secours.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
                        'Aucun scan pour l’instant. Tes tickets validés '
                        'apparaîtront ici.',
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
                    onDelete: () => _deleteScanWithUndo(context, scan),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _deleteScanWithUndo(BuildContext context, ScanHistoryItem scan) {
    final originalIndex = historyStore.items.indexWhere(
      (item) => item.id == scan.id,
    );
    if (originalIndex == -1) return;

    historyStore.deleteScan(scan.id);

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Scan supprimé de l’historique'),
        action: SnackBarAction(
          label: 'Annuler',
          onPressed: () {
            historyStore.restoreScan(scan, index: originalIndex);
          },
        ),
      ),
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
                      _formatScanDate(scan.scannedAt),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${scan.sourceLabel} • ${scan.statusLabel}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scan.usedFallback
                            ? colorScheme.error
                            : colorScheme.primary,
                        fontWeight: FontWeight.w700,
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
              const SizedBox(height: 14),
              _ScanDiagnosticBox(scan: scan),
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

class _ScanDiagnosticBox extends StatelessWidget {
  const _ScanDiagnosticBox({required this.scan});

  final ScanHistoryItem scan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _DiagnosticRow(label: 'Source', value: scan.sourceLabel),
          _DiagnosticRow(label: 'Statut', value: scan.statusLabel),
          _DiagnosticRow(
            label: 'Produits validés',
            value: '${scan.validatedCount}/${scan.detectedCount}',
          ),
          if (scan.model != null && scan.model!.trim().isNotEmpty)
            _DiagnosticRow(label: 'Modèle', value: scan.model!),
          if (scan.errorMessage != null && scan.errorMessage!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Le service d’analyse n’était pas disponible lors de ce scan. '
                'Les résultats ont dû être vérifiés manuellement.',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _formatScanDate(DateTime date) {
  final now = DateTime.now();
  final isToday =
      date.year == now.year && date.month == now.month && date.day == now.day;
  final day = isToday
      ? 'Aujourd’hui'
      : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day à $hour:$minute';
}

class _TicketPreviewCard extends StatelessWidget {
  const _TicketPreviewCard({required this.imageBytes, required this.maxHeight});

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
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      size: 42,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Image non lisible',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choisis une autre photo avant de lancer l’analyse.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ScanValidationSheet extends StatefulWidget {
  const _ScanValidationSheet({
    required this.detectedDrafts,
    required this.usedFallback,
    required this.onCancel,
    required this.onValidate,
  });

  final List<DetectedProductDraft> detectedDrafts;
  final bool usedFallback;
  final VoidCallback onCancel;
  final void Function(List<FoodItem> selectedFoods) onValidate;

  @override
  State<_ScanValidationSheet> createState() => _ScanValidationSheetState();
}

class _ScanValidationSheetState extends State<_ScanValidationSheet> {
  late List<DetectedProductDraft> _items;
  StorageLocation _storageLocation = StorageLocation.fridge;

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

  void _changeUnit(String id, String unit) {
    setState(() {
      _items = _items.map((draft) {
        if (draft.id != id) return draft;
        return draft.copyWith(
          amount: MeasurementHelper.amountAfterUnitChange(
            draft.amount,
            fromUnit: draft.unit,
            toUnit: unit,
          ),
          unit: unit,
        );
      }).toList();
    });
  }

  Future<void> _changeExpiryDate(DetectedProductDraft draft) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: draft.estimatedExpirationDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
      helpText: 'Modifier la date estimée',
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );

    if (picked == null || !mounted) return;

    setState(() {
      _items = _items.map((item) {
        if (item.id != draft.id) return item;
        return item.copyWith(
          estimatedExpirationDate: DateTime(
            picked.year,
            picked.month,
            picked.day,
          ),
        );
      }).toList();
    });
  }

  Future<void> _addProductManually() {
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
              final draft = DetectedProductDraft(
                id: 'manual_${DateTime.now().microsecondsSinceEpoch}',
                name: food.name,
                category: food.category,
                estimatedExpirationDate: food.expiryDate,
                quantity: food.quantity,
                amount: food.amount,
                unit: food.unit,
              );

              setState(() => _items = [..._items, draft]);
              Navigator.pop(sheetContext);
            },
          ),
        );
      },
    );
  }

  List<FoodItem> _foodsForFridge() {
    return _items
        .map(
          (draft) =>
              draft.toFoodItem().copyWith(storageLocation: _storageLocation),
        )
        .toList();
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
                          color: colorScheme.primaryContainer.withValues(
                            alpha: 0.5,
                          ),
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
                              'Corrige la liste avant de l’ajouter au stock.',
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
                    'Tu peux modifier les quantités, les unités et les dates '
                    'estimées, supprimer une ligne ou ajouter un produit '
                    'oublié. Rien ne sera ajouté avant ta validation.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<StorageLocation>(
                    initialValue: _storageLocation,
                    decoration: InputDecoration(
                      labelText: 'Emplacement pour ces produits',
                      prefixIcon: Icon(
                        StorageLocationHelper.icon(_storageLocation),
                      ),
                    ),
                    items: StorageLocation.values.map((location) {
                      return DropdownMenuItem(
                        value: location,
                        child: Text(StorageLocationHelper.label(location)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _storageLocation = value);
                    },
                  ),
                  if (widget.usedFallback) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer.withValues(
                          alpha: 0.55,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Mode démo utilisé : le service IA était indisponible. '
                        'Vérifie attentivement chaque produit.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
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
                    onUnitChanged: (unit) => _changeUnit(draft.id, unit),
                    onExpiryDateChanged: () => _changeExpiryDate(draft),
                    onRemove: () => _removeItem(draft.id),
                  );
                },
              ),
            ),
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Text(
                  'Aucun produit sélectionné. Annule ou relance un scan.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _addProductManually,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Ajouter un produit oublié'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cancelButton = OutlinedButton(
                    onPressed: widget.onCancel,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Annuler sans ajouter'),
                  );
                  final validateButton = FilledButton(
                    onPressed: canValidate
                        ? () => widget.onValidate(_foodsForFridge())
                        : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Valider et ajouter'),
                  );

                  if (constraints.maxWidth < 340) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        validateButton,
                        const SizedBox(height: 10),
                        cancelButton,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: cancelButton),
                      const SizedBox(width: 12),
                      Expanded(child: validateButton),
                    ],
                  );
                },
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
    required this.onUnitChanged,
    required this.onExpiryDateChanged,
    required this.onRemove,
  });

  final DetectedProductDraft draft;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final ValueChanged<String> onUnitChanged;
  final VoidCallback onExpiryDateChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final expiryLabel = ExpiryHelper.labelFor(draft.estimatedExpirationDate);

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
          final stackControls = constraints.maxWidth < 430;

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
              TextButton.icon(
                onPressed: onExpiryDateChanged,
                icon: const Icon(Icons.event_rounded, size: 16),
                label: Text('Date estimée : $expiryLabel · Modifier'),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: theme.textTheme.bodySmall,
                ),
              ),
            ],
          );

          final controlsRow = Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 8,
            children: [
              _QuantityStepper(
                amountLabel: draft.amountLabel,
                canDecrement:
                    draft.amount > MeasurementHelper.stepFor(draft.unit),
                onDecrement: onDecrement,
                onIncrement: onIncrement,
              ),
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                initialValue: draft.unit,
                tooltip: 'Modifier l’unité',
                onSelected: onUnitChanged,
                itemBuilder: (context) {
                  return MeasurementHelper.units.map((unit) {
                    return PopupMenuItem<String>(
                      value: unit,
                      child: Text(unit),
                    );
                  }).toList();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        draft.unit,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_drop_down_rounded, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Supprimer'),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  visualDensity: VisualDensity.compact,
                ),
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
                Align(alignment: Alignment.centerRight, child: controlsRow),
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
    _expiryDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 7));
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
    setState(
      () => _expiryDate = DateTime(picked.year, picked.month, picked.day),
    );
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
                        color: colorScheme.primaryContainer.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.edit_rounded,
                        color: colorScheme.primary,
                      ),
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
                        canDecrement:
                            _amount > MeasurementHelper.stepFor(_unit),
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
                            _amount = MeasurementHelper.amountAfterUnitChange(
                              _amount,
                              fromUnit: _unit,
                              toUnit: value,
                            );
                            _unit = value;
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
                  label: Text(
                    'DLC estimée : ${ExpiryHelper.labelFor(_expiryDate)}',
                  ),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
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
            const SizedBox(height: 8),
            Text(
              'Gemini recherche les produits. Tu pourras tout vérifier '
              'et corriger avant l’ajout au frigo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
