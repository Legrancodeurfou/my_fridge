import 'dart:math';
import 'dart:typed_data';

import '../models/detected_product_draft.dart';
import '../models/ticket_analysis_result.dart';
import 'ticket_analysis_prompt.dart';

enum TicketAnalysisMode { demo, gemini }

/// Analyse d’image de ticket de caisse.
///
/// État actuel :
/// - mode démo actif par défaut pour ne rien casser ;
/// - prompt Gemini préparé ;
/// - futur branchement IA isolé dans [_analyzeWithGemini].
class TicketAnalysisService {
  const TicketAnalysisService({
    this.mode = TicketAnalysisMode.demo,
  });

  final TicketAnalysisMode mode;

  /// Analyse l’image et renvoie les produits à valider.
  Future<List<DetectedProductDraft>> analyzeTicket(Uint8List imageBytes) async {
    return switch (mode) {
      TicketAnalysisMode.demo => _analyzeWithDemo(imageBytes),
      TicketAnalysisMode.gemini => _analyzeWithGemini(imageBytes),
    };
  }

  /// Mode actuel de l’app : simulation locale sans IA.
  Future<List<DetectedProductDraft>> _analyzeWithDemo(Uint8List imageBytes) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    return _simulateAnalysis(imageBytes).products;
  }

  /// Futur mode Gemini.
  ///
  /// Important : ne mets pas de clé API Gemini directement dans Flutter.
  /// La prochaine étape propre sera :
  /// Flutter -> backend sécurisé -> Gemini API -> JSON -> Flutter.
  ///
  /// Pour l’instant, cette méthode prépare le prompt et garde un fallback démo,
  /// afin que l’app reste utilisable même sans backend ni clé API.
  Future<List<DetectedProductDraft>> _analyzeWithGemini(Uint8List imageBytes) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Prêt pour l’appel backend/Gemini :
    // - modèle cible : TicketAnalysisPrompt.geminiModel
    // - prompt : prompt
    // - image : imageBytes
    final prompt = TicketAnalysisPrompt.build(today: today);

    // Évite les warnings d’analyse tant que l’appel IA n’est pas branché.
    // ignore: unused_local_variable
    final geminiRequestPreview = {
      'model': TicketAnalysisPrompt.geminiModel,
      'prompt': prompt,
      'imageBytesLength': imageBytes.length,
    };

    // Fallback temporaire : on conserve exactement le comportement actuel.
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
  /// Format proche d’une future réponse IA :
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
