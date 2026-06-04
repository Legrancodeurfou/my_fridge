abstract final class TicketAnalysisPrompt {
  static const prompt = '''
Analyse cette image de ticket de caisse.

Objectif : extraire uniquement les produits alimentaires achetés.

Ignore toujours :
- total, sous-total, TVA, taxes
- mode de paiement, carte bancaire, monnaie, rendu monnaie
- remises, promotions, fidélité, coupons
- sacs, emballages, services, frais
- numéro de ticket, magasin, adresse, horaires

Retourne uniquement un JSON strict, sans Markdown, sans explication, sans texte avant ou après.

Format exact attendu :
[
  {
    "name": "Nom simple du produit",
    "quantity": 1,
    "amount": 500,
    "unit": "g",
    "category": "other",
    "estimatedShelfLifeDays": 30
  }
]

Règles importantes :
- "name" doit être lisible et simple en français. Exemple : "Crème fraîche" au lieu de "CREME FR 30%".
- "quantity" = nombre d'unités logiques. Exemple : 6 œufs => 6, 500 g de pâtes => 1.
- "amount" = quantité affichable. Exemple : 500 pour 500 g, 20 pour 20 cl, 6 pour 6 œufs.
- "unit" doit être une seule des valeurs suivantes : "g", "kg", "ml", "cl", "l", "unité", "tranche".
- "category" doit être une seule des valeurs suivantes : "dairy", "produce", "meat", "other".
- "estimatedShelfLifeDays" doit être un nombre entier réaliste selon le produit.
- Si une information est incertaine, fais une estimation raisonnable.
- Si aucun produit alimentaire n'est détecté, retourne [].
''';
}
