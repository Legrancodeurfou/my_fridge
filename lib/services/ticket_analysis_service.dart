import 'dart:typed_data';

import '../models/detected_product_draft.dart';
import '../models/ticket_analysis_result.dart';

/// Analyse d’image de ticket de caisse (simulation MVP, sans IA).
class TicketAnalysisService {
  const TicketAnalysisService();

  /// Analyse l’image et renvoie les produits à valider.
  ///
  /// [imageBytes] sera envoyé à l’IA plus tard ; ignoré pour la simulation.
  Future<List<DetectedProductDraft>> analyzeTicket(Uint8List imageBytes) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    return _simulateAnalysis(imageBytes).products;
  }

  TicketAnalysisResult _simulateAnalysis(Uint8List imageBytes) {
    // ignore: unused_local_variable
    final _ = imageBytes;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final idPrefix = now.millisecondsSinceEpoch.toString();

    return TicketAnalysisResult.fromJsonList(
      _mockTicketJson(today),
      idPrefix: idPrefix,
    );
  }

  /// JSON fictif calqué sur le format attendu d’une future réponse IA.
  static List<Map<String, dynamic>> _mockTicketJson(DateTime today) {
    return [
      {
        'name': 'Pâtes',
        'quantity': 1,
        'category': 'other',
        'estimatedExpirationDate':
            today.add(const Duration(days: 365)).toIso8601String(),
      },
      {
        'name': 'Jambon',
        'quantity': 1,
        'category': 'meat',
        'estimatedExpirationDate':
            today.add(const Duration(days: 5)).toIso8601String(),
      },
      {
        'name': 'Crème fraîche',
        'quantity': 1,
        'category': 'dairy',
        'estimatedExpirationDate':
            today.add(const Duration(days: 10)).toIso8601String(),
      },
      {
        'name': 'Salade',
        'quantity': 1,
        'category': 'produce',
        'estimatedExpirationDate':
            today.add(const Duration(days: 3)).toIso8601String(),
      },
    ];
  }
}
