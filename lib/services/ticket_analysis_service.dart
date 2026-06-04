import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/detected_product_draft.dart';
import '../models/ticket_analysis_result.dart';
import 'ticket_analysis_http_client.dart';

/// Mode d'analyse du ticket.
///
/// - demo : conserve les tickets fictifs actuels.
/// - gemini : tente d'appeler la Netlify Function sécurisée, puis retombe en
///   mode demo si l'appel échoue.
enum TicketAnalysisMode { demo, gemini }

/// Analyse d'image de ticket de caisse.
///
/// Version actuelle : hybride.
/// 1. Essaie Gemini via une Netlify Function.
/// 2. Si l'API n'est pas configurée, indisponible ou invalide, garde le mode démo.
class TicketAnalysisService {
  const TicketAnalysisService({
    this.mode = TicketAnalysisMode.gemini,
    this.endpoint = _defaultFunctionEndpoint,
  });

  static const _defaultFunctionEndpoint = '/.netlify/functions/analyze-ticket';

  final TicketAnalysisMode mode;
  final String endpoint;

  /// Analyse l'image et renvoie les produits à valider.
  Future<List<DetectedProductDraft>> analyzeTicket(Uint8List imageBytes) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (mode == TicketAnalysisMode.gemini) {
      try {
        final geminiResult = await _analyzeWithGemini(imageBytes);
        if (geminiResult.products.isNotEmpty) {
          return geminiResult.products;
        }
      } catch (error) {
        debugPrint('Analyse Gemini indisponible, fallback démo : $error');
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 900));
    return _simulateAnalysis(imageBytes).products;
  }

  Future<TicketAnalysisResult> _analyzeWithGemini(Uint8List imageBytes) async {
    final now = DateTime.now();
    final idPrefix = 'gemini_${now.microsecondsSinceEpoch}';

    final responseText = await postAnalyzeTicket(
      endpoint,
      {
        'imageBase64': base64Encode(imageBytes),
        'mimeType': 'image/jpeg',
      },
    );

    final decoded = jsonDecode(responseText);
    final productsJson = switch (decoded) {
      final List<dynamic> list => list,
      final Map<String, dynamic> map when map['products'] is List<dynamic> =>
        map['products'] as List<dynamic>,
      _ => throw const FormatException('Réponse IA invalide'),
    };

    return TicketAnalysisResult.fromJsonList(
      productsJson,
      idPrefix: idPrefix,
    );
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

  /// Tickets fictifs gardés comme fallback si Gemini n'est pas disponible.
  static List<List<Map<String, dynamic>>> _mockTickets(DateTime today) {
    return [
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
