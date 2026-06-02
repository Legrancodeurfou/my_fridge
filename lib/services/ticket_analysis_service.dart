import 'dart:math';
import 'dart:typed_data';

import '../models/detected_product_draft.dart';
import '../models/ticket_analysis_result.dart';

/// Analyse d’image de ticket de caisse.
///
/// Version MVP actuelle : simulation sans IA.
/// Chaque scan renvoie un ticket fictif différent pour tester l’app.
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

    final tickets = _mockTickets(today);
    final ticketIndex = Random().nextInt(tickets.length);

    return TicketAnalysisResult.fromJsonList(
      tickets[ticketIndex],
      idPrefix: idPrefix,
    );
  }

  /// Plusieurs tickets fictifs pour rendre la démo moins répétitive.
  ///
  /// Format volontairement proche d’une future réponse IA :
  /// name, quantity, amount, unit, category, estimatedExpirationDate.
  static List<List<Map<String, dynamic>>> _mockTickets(DateTime today) {
    return [
      // Ticket 1 — ancien ticket de démo
      [
        {
          'name': 'Pâtes',
          'quantity': 1,
          'amount': 500,
          'unit': 'g',
          'category': 'other',
          'estimatedExpirationDate':
              today.add(const Duration(days: 365)).toIso8601String(),
        },
        {
          'name': 'Jambon',
          'quantity': 2,
          'amount': 2,
          'unit': 'tranche',
          'category': 'meat',
          'estimatedExpirationDate':
              today.add(const Duration(days: 5)).toIso8601String(),
        },
        {
          'name': 'Crème fraîche',
          'quantity': 1,
          'amount': 20,
          'unit': 'cl',
          'category': 'dairy',
          'estimatedExpirationDate':
              today.add(const Duration(days: 10)).toIso8601String(),
        },
        {
          'name': 'Salade',
          'quantity': 1,
          'amount': 1,
          'unit': 'unité',
          'category': 'produce',
          'estimatedExpirationDate':
              today.add(const Duration(days: 3)).toIso8601String(),
        },
      ],

      // Ticket 2 — repas simple poulet/riz
      [
        {
          'name': 'Riz',
          'quantity': 1,
          'amount': 500,
          'unit': 'g',
          'category': 'other',
          'estimatedExpirationDate':
              today.add(const Duration(days: 365)).toIso8601String(),
        },
        {
          'name': 'Poulet',
          'quantity': 1,
          'amount': 400,
          'unit': 'g',
          'category': 'meat',
          'estimatedExpirationDate':
              today.add(const Duration(days: 3)).toIso8601String(),
        },
        {
          'name': 'Courgettes',
          'quantity': 3,
          'amount': 3,
          'unit': 'unité',
          'category': 'produce',
          'estimatedExpirationDate':
              today.add(const Duration(days: 5)).toIso8601String(),
        },
        {
          'name': 'Yaourt nature',
          'quantity': 4,
          'amount': 4,
          'unit': 'unité',
          'category': 'dairy',
          'estimatedExpirationDate':
              today.add(const Duration(days: 12)).toIso8601String(),
        },
      ],

      // Ticket 3 — brunch / salade tomate mozza
      [
        {
          'name': 'Pain',
          'quantity': 6,
          'amount': 6,
          'unit': 'tranche',
          'category': 'other',
          'estimatedExpirationDate':
              today.add(const Duration(days: 4)).toIso8601String(),
        },
        {
          'name': 'Œufs',
          'quantity': 6,
          'amount': 6,
          'unit': 'unité',
          'category': 'other',
          'estimatedExpirationDate':
              today.add(const Duration(days: 14)).toIso8601String(),
        },
        {
          'name': 'Tomates',
          'quantity': 4,
          'amount': 4,
          'unit': 'unité',
          'category': 'produce',
          'estimatedExpirationDate':
              today.add(const Duration(days: 4)).toIso8601String(),
        },
        {
          'name': 'Mozzarella',
          'quantity': 1,
          'amount': 125,
          'unit': 'g',
          'category': 'dairy',
          'estimatedExpirationDate':
              today.add(const Duration(days: 7)).toIso8601String(),
        },
      ],

      // Ticket 4 — produits rapides
      [
        {
          'name': 'Tortillas',
          'quantity': 6,
          'amount': 6,
          'unit': 'unité',
          'category': 'other',
          'estimatedExpirationDate':
              today.add(const Duration(days: 20)).toIso8601String(),
        },
        {
          'name': 'Steak haché',
          'quantity': 1,
          'amount': 250,
          'unit': 'g',
          'category': 'meat',
          'estimatedExpirationDate':
              today.add(const Duration(days: 2)).toIso8601String(),
        },
        {
          'name': 'Emmental',
          'quantity': 1,
          'amount': 200,
          'unit': 'g',
          'category': 'dairy',
          'estimatedExpirationDate':
              today.add(const Duration(days: 15)).toIso8601String(),
        },
        {
          'name': 'Avocat',
          'quantity': 2,
          'amount': 2,
          'unit': 'unité',
          'category': 'produce',
          'estimatedExpirationDate':
              today.add(const Duration(days: 3)).toIso8601String(),
        },
      ],
    ];
  }
}