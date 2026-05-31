import 'dart:typed_data';

import '../data/fridge_store.dart';
import '../models/food.dart';

/// Analyse d’image de ticket de caisse (simulation MVP, sans IA).
class TicketAnalysisService {
  const TicketAnalysisService();

  /// Analyse les octets de l’image et retourne les produits détectés.
  ///
  /// [imageBytes] est conservé pour une future intégration réelle ; non utilisé
  /// dans la simulation actuelle.
  Future<List<FoodItem>> analyzeTicket(Uint8List imageBytes) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    return FridgeStore.createTicketScanItems();
  }
}
