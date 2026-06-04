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
- produits clairement non alimentaires

Retourne uniquement un JSON strict, sans Markdown, sans explication, sans texte avant ou après.

Format exact attendu :
[
  {
    "name": "Nom simple du produit",
    "quantity": 1,
    "amount": 1,
    "unit": "unité",
    "category": "other",
    "estimatedShelfLifeDays": 30
  }
]

Unités autorisées uniquement : "g", "kg", "ml", "cl", "l", "unité", "tranche".
Catégories autorisées uniquement : "dairy", "produce", "meat", "other".

Règles très importantes :
- N'invente jamais un poids, un volume ou un nombre de tranches si l'information n'est pas clairement visible sur le ticket.
- Si le poids, le volume ou le nombre précis n'est pas visible, retourne simplement : quantity = 1, amount = 1, unit = "unité".
- Pour les produits comme pâtes, riz, biscuits, chocolat, conserve, sauce, pain, fromage emballé : si le poids n'est pas visible, mets 1 unité. Ne mets pas 500 g par défaut.
- Pour les produits naturellement comptables, garde le nombre uniquement s'il est visible ou clairement indiqué : œufs, yaourts, fruits, légumes, tranches de jambon, tranches de pain.
- Exemple : "Jambon 6 tranches" visible => quantity = 6, amount = 6, unit = "tranche".
- Exemple : "Jambon" sans nombre visible => quantity = 1, amount = 1, unit = "unité".
- Exemple : "Riz" sans poids visible => quantity = 1, amount = 1, unit = "unité".
- Exemple : "Pâtes" sans poids visible => quantity = 1, amount = 1, unit = "unité".
- Exemple : "Lait 1L" visible => quantity = 1, amount = 1, unit = "l".
- "name" doit être lisible et simple en français. Exemple : "Crème fraîche" au lieu de "CREME FR 30%".
- "quantity" = nombre d'unités logiques. Exemple : 6 œufs => 6, 500 g de pâtes => 1.
- "amount" = quantité affichable. Exemple : 500 pour 500 g, 20 pour 20 cl, 6 pour 6 œufs.
- "estimatedShelfLifeDays" doit être un nombre entier réaliste selon le produit.
- Si aucun produit alimentaire n'est détecté, retourne [].
''';
}
