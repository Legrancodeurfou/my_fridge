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

enum TicketAnalysisSource { demo, gemini }

class TicketAnalysisReport {
  const TicketAnalysisReport({
    required this.products,
    required this.source,
    this.model,
    this.errorMessage,
  });

  final List<DetectedProductDraft> products;
  final TicketAnalysisSource source;
  final String? model;
  final String? errorMessage;

  bool get usedGemini => source == TicketAnalysisSource.gemini;
  bool get usedFallback => source == TicketAnalysisSource.demo && errorMessage != null;

  String get sourceLabel {
    return switch (source) {
      TicketAnalysisSource.gemini => 'Gemini',
      TicketAnalysisSource.demo => 'Mode démo',
    };
  }
}

/// Analyse d'image de ticket de caisse.
///
/// Version actuelle : hybride.
/// 1. En mode gemini, essaie Gemini via une Netlify Function.
/// 2. En mode demo, utilise les tickets fictifs.
///
/// Important : en mode gemini, on ne retombe plus silencieusement sur des
/// produits fictifs. Si Gemini échoue, l'erreur est affichée côté UI.
class TicketAnalysisService {
  const TicketAnalysisService({
    this.mode = TicketAnalysisMode.gemini,
    this.endpoint = _defaultFunctionEndpoint,
  });

  static const _defaultFunctionEndpoint = '/.netlify/functions/analyze-ticket';

  final TicketAnalysisMode mode;
  final String endpoint;

  /// Analyse l'image et renvoie seulement les produits.
  /// Garde cette méthode pour compatibilité avec le reste de l'app.
  Future<List<DetectedProductDraft>> analyzeTicket(Uint8List imageBytes) async {
    final report = await analyzeTicketDetailed(imageBytes);
    return report.products;
  }

  /// Analyse l'image et renvoie aussi les informations de diagnostic.
  Future<TicketAnalysisReport> analyzeTicketDetailed(Uint8List imageBytes) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (mode == TicketAnalysisMode.gemini) {
      try {
        final geminiReport = await _analyzeWithGemini(imageBytes);
        if (geminiReport.products.isNotEmpty) {
          return geminiReport;
        }
      } catch (error) {
        debugPrint('Analyse Gemini indisponible : $error');
        throw Exception(
          'Analyse Gemini indisponible. Si tu testes en local, utilise le site Netlify déployé ou lance Netlify Dev. Détail : $error',
        );
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 900));
    return TicketAnalysisReport(
      products: _simulateAnalysis(imageBytes).products,
      source: TicketAnalysisSource.demo,
    );
  }

  Future<TicketAnalysisReport> _analyzeWithGemini(Uint8List imageBytes) async {
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
    final model = decoded is Map<String, dynamic> ? decoded['model'] as String? : null;
    final productsJson = switch (decoded) {
      final List<dynamic> list => list,
      final Map<String, dynamic> map when map['products'] is List<dynamic> =>
        map['products'] as List<dynamic>,
      _ => throw const FormatException('Réponse IA invalide'),
    };

    final result = TicketAnalysisResult.fromJsonList(
      productsJson,
      idPrefix: idPrefix,
    );

    return TicketAnalysisReport(
      products: result.products,
      source: TicketAnalysisSource.gemini,
      model: model,
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
