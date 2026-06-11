const MODEL = process.env.GEMINI_MODEL || 'gemini-3.1-flash-lite';
const MAX_BODY_BYTES = 8 * 1024 * 1024;
const MAX_IMAGE_BASE64_LENGTH = 7 * 1024 * 1024;
const GEMINI_TIMEOUT_MS = 25_000;
const {
  normalizeShelfLifeDays,
} = require('./shelf-life-estimator');

const PROMPT = `
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
    "estimatedShelfLifeDays": 30,
    "storageLocation": "fridge"
  }
]

Unités autorisées uniquement : "g", "kg", "ml", "cl", "l", "unité", "tranche".
Catégories autorisées uniquement : "dairy", "produce", "meat", "other".
Emplacements autorisés uniquement : "fridge", "pantry", "freezer", "spices".

Règles très importantes :
- Une quantité n'est valide que si elle est explicitement liée à la désignation du produit sur la même ligne ou dans son libellé : par exemple "500 g", "1 L", "x6" ou "6 tranches".
- N'utilise jamais un chiffre provenant d'une colonne secondaire du ticket comme quantité : TVA, taux de taxe, prix unitaire, prix total de ligne, remise, pourcentage, code rayon ou référence.
- La proximité visuelle avec une ligne produit ne suffit pas : un chiffre isolé sans unité ou multiplicateur clairement associé au produit n'est pas un grammage ni un nombre d'unités.
- N'invente jamais un poids, un volume ou un nombre de tranches si l'information n'est pas clairement visible et rattachée au produit.
- Si le poids, le volume ou le nombre précis n'est pas visible, retourne simplement : quantity = 1, amount = 1, unit = "unité".
- En cas de doute sur l'unité ou sur l'origine d'un chiffre, préfère toujours quantity = 1, amount = 1, unit = "unité".
- Pour les produits comme pâtes, riz, biscuits, chocolat, conserve, sauce, pain, fromage emballé : si le poids n'est pas visible, mets 1 unité. Ne mets pas 500 g par défaut.
- Pour les produits naturellement comptables, garde le nombre uniquement s'il est visible ou clairement indiqué : œufs, yaourts, fruits, légumes, tranches de jambon, tranches de pain.
- Ne convertis jamais un prix décimal, un taux de TVA ou un pourcentage en quantité, même si aucune autre quantité n'est visible.

Exemples négatifs obligatoires :
- Une colonne "TVA 5.5", "TVA 10" ou "TVA 20" ne doit jamais produire 5.5 g, 10 unités, 20 unités ou toute autre quantité.
- Un prix "2.99" ou "2,99 €" ne doit jamais produire quantity = 2.99, amount = 2.99 ou 2.99 unités.
- Un total de ligne, sous-total, montant de remise ou pourcentage ne doit jamais devenir quantity ou amount.
- Ligne produit "FROMAGE ORIGINAL" avec TVA 20 et prix 2.99, sans grammage lisible => quantity = 1, amount = 1, unit = "unité".

Règles de lecture du nom produit :
- Préserve en priorité les mots et marques réellement visibles. Si le produit est ambigu, garde un nom proche du libellé original plutôt que de le transformer en un autre aliment.
- Les abréviations "btr" ou "beurre" doivent être interprétées prudemment. "btr" seul ne suffit pas pour renommer un produit en "Beurre" si d'autres mots ou une marque indiquent autre chose.
- "Leerdammer" et les marques ou mentions clairement associées au fromage doivent rester classées comme fromage, catégorie "dairy", même si une abréviation voisine semble évoquer du beurre.
- Exemple : si "LEERDAMMER", "FROMAGE" ou une marque de fromage est visible avec "200 g", retourne un nom de fromage et 200 g ; ne retourne pas "Beurre".
- Si seule une désignation ambiguë comme "200G BTR ORIGINAL" est lisible et qu'aucune identité produit fiable n'est visible, conserve un nom proche de "BTR Original" au lieu d'inventer "Beurre".

Règles d'emplacement conseillé :
- "freezer" : glace, crème glacée, produit surgelé, mention "frozen" ou bac de glace.
- "pantry" : pâtes, riz, farine, sucre, conserves, biscuits, chips, pains au chocolat et céréales.
- "fridge" : jambon, viande, poisson, lait, yaourt, fromage, beurre, crème et salade fraîche.
- "spices" : sel, poivre, paprika, curry, herbes, épices et bouillon.
- Choisis l'emplacement produit par produit.
- Si le produit ou son mode de conservation est ambigu, utilise "fridge" par prudence.
- N'invente jamais un emplacement à partir du rayon, du prix, de la TVA ou d'un chiffre du ticket.

Exemples positifs :
- Exemple : "Jambon 6 tranches" visible => quantity = 6, amount = 6, unit = "tranche".
- Exemple : "Jambon" sans nombre visible => quantity = 1, amount = 1, unit = "unité".
- Exemple : "Riz" sans poids visible => quantity = 1, amount = 1, unit = "unité".
- Exemple : "Pâtes" sans poids visible => quantity = 1, amount = 1, unit = "unité".
- Exemple : "Lait 1L" visible => quantity = 1, amount = 1, unit = "l".
- "name" doit être lisible et simple en français. Exemple : "Crème fraîche" au lieu de "CREME FR 30%".
- "quantity" = nombre d'unités logiques. Exemple : 6 œufs => 6, 500 g de pâtes => 1.
- "amount" = quantité affichable. Exemple : 500 pour 500 g, 20 pour 20 cl, 6 pour 6 œufs.
- "estimatedShelfLifeDays" est une estimation prudente, pas une vraie DLC. Elle doit être un nombre entier réaliste selon le produit.
- Repères : jambon ou charcuterie sous vide environ 14 jours ; emmental, Leerdammer ou fromage emballé 30 à 45 jours ; roquefort ou fromage bleu 45 à 60 jours ; beurre 45 à 60 jours.
- Repères : lait frais 7 à 10 jours ; yaourt 20 à 30 jours ; salade ou légumes frais 3 à 5 jours ; fruits 5 à 10 jours.
- Repères : pâtes, riz, conserves, chips et biscuits plusieurs mois ; épices encore plus longtemps.
- Si le produit est ambigu, choisis une durée raisonnable sans inventer une date précise ni utiliser un chiffre du ticket.
- Si aucun produit alimentaire n'est détecté, retourne [].
`;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Max-Age': '86400',
};

exports.handler = async (event) => {
  const method = event.httpMethod?.toUpperCase();

  if (method === 'OPTIONS') {
    return {
      statusCode: 204,
      headers: corsHeaders,
      body: '',
    };
  }

  if (method !== 'POST') {
    return jsonResponse(405, { error: 'Méthode non autorisée.' });
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    console.error('GEMINI_API_KEY is missing.');
    return jsonResponse(503, {
      error: 'Le service d’analyse est temporairement indisponible.',
    });
  }

  const rawBody = event.body || '';
  if (Buffer.byteLength(rawBody, 'utf8') > MAX_BODY_BYTES) {
    return jsonResponse(413, {
      error: 'L’image envoyée est trop volumineuse.',
    });
  }

  let payload;
  try {
    payload = JSON.parse(rawBody);
  } catch (_) {
    return jsonResponse(400, { error: 'Le contenu envoyé est invalide.' });
  }

  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    return jsonResponse(400, { error: 'Le contenu envoyé est invalide.' });
  }

  const imageBase64 = payload.imageBase64;
  const mimeType = payload.mimeType || 'image/jpeg';

  if (typeof imageBase64 !== 'string' || imageBase64.trim().length === 0) {
    return jsonResponse(400, { error: 'Aucune image valide n’a été envoyée.' });
  }

  if (imageBase64.length > MAX_IMAGE_BASE64_LENGTH) {
    return jsonResponse(413, {
      error: 'L’image envoyée est trop volumineuse.',
    });
  }

  try {
    const geminiResponse = await callGemini({
      apiKey,
      imageBase64,
      mimeType,
    });

    const text = extractGeminiText(geminiResponse);
    const products = normalizeProducts(parseJsonText(text));

    return jsonResponse(200, {
      source: 'gemini',
      model: MODEL,
      products,
    });
  } catch (error) {
    console.error('Ticket analysis failed:', error);

    const timedOut = error?.name === 'AbortError';
    return jsonResponse(timedOut ? 504 : 502, {
      error: timedOut
        ? 'Le service d’analyse met trop de temps à répondre.'
        : 'Le service d’analyse est temporairement indisponible.',
    });
  }
};

async function callGemini({ apiKey, imageBase64, mimeType }) {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${apiKey}`;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), GEMINI_TIMEOUT_MS);

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      signal: controller.signal,
      body: JSON.stringify({
        contents: [
          {
            role: 'user',
            parts: [
              { text: PROMPT },
              {
                inline_data: {
                  mime_type: mimeType,
                  data: imageBase64,
                },
              },
            ],
          },
        ],
        generationConfig: {
          temperature: 0,
          response_mime_type: 'application/json',
        },
      }),
    });

    const text = await response.text();

    if (!response.ok) {
      throw new Error(`Gemini API error ${response.status}: ${text}`);
    }

    return JSON.parse(text);
  } finally {
    clearTimeout(timeout);
  }
}

function extractGeminiText(response) {
  const text = response?.candidates?.[0]?.content?.parts
    ?.map((part) => part.text || '')
    .join('')
    .trim();

  if (!text) {
    throw new Error('Gemini returned an empty response.');
  }

  return text;
}

function parseJsonText(text) {
  const cleaned = text
    .replace(/^```json\s*/i, '')
    .replace(/^```\s*/i, '')
    .replace(/```$/i, '')
    .trim();

  const parsed = JSON.parse(cleaned);

  if (!Array.isArray(parsed)) {
    throw new Error('Gemini response is not a JSON array.');
  }

  return parsed;
}

function normalizeProducts(rawProducts) {
  const today = new Date();

  return rawProducts
    .map((raw) => normalizeProduct(raw, today))
    .filter(Boolean);
}

function normalizeProduct(raw, today) {
  const name = cleanProductName(raw.name);
  if (!name) return null;

  const unitInfo = normalizeUnit(raw.unit);
  const hasUsableAmount = hasPositiveNumber(raw.amount);
  const hasUsableQuantity = hasPositiveNumber(raw.quantity);
  const rawAmount = Number(raw.amount);
  const rawQuantity = Number(raw.quantity);

  let unit = unitInfo.unit;
  let amount;
  let quantity;

  // Si Gemini n'a pas fourni d'unité reconnue ou n'a pas fourni de quantité
  // affichable claire, on évite d'inventer un poids/volume.
  if (!unitInfo.isRecognized || !hasUsableAmount) {
    unit = 'unité';
    amount = hasUsableQuantity ? Math.max(1, Math.round(rawQuantity)) : 1;
    quantity = Math.max(1, Math.round(amount));
  } else {
    amount = rawAmount;
    quantity = normalizeQuantity(raw.quantity, amount, unit);
  }

  // Dernier garde-fou : pas de valeurs absurdes en unités ou tranches.
  if ((unit === 'unité' || unit === 'tranche') && amount > 99) {
    amount = 1;
    quantity = 1;
    unit = 'unité';
  }

  const category = normalizeCategory(raw.category);
  const storageLocation = normalizeStorageLocation(raw.storageLocation, name);
  const shelfLifeDays = normalizeShelfLifeDays(
    raw.estimatedShelfLifeDays,
    category,
    name,
  );

  const expirationDate = new Date(today);
  expirationDate.setDate(expirationDate.getDate() + shelfLifeDays);

  return {
    name,
    quantity,
    amount,
    unit,
    category,
    storageLocation,
    estimatedExpirationDate: expirationDate.toISOString(),
  };
}

function cleanProductName(value) {
  const name = cleanString(value)
    .replace(/\s+/g, ' ')
    .replace(/\b(x|X)\s?\d+\b/g, '')
    .replace(/\b\d+[,.]?\d*\s?(g|kg|ml|cl|l)\b/gi, '')
    .trim();

  if (!name || name.length < 2) return '';

  return name.charAt(0).toUpperCase() + name.slice(1);
}

function cleanString(value) {
  if (typeof value !== 'string') return '';
  return value.trim().replace(/\s+/g, ' ');
}

function hasPositiveNumber(value) {
  const number = Number(value);
  return Number.isFinite(number) && number > 0;
}

function normalizeQuantity(value, amount, unit) {
  const number = Number(value);

  if (Number.isFinite(number) && number >= 1) {
    return Math.round(number);
  }

  if (unit === 'unité' || unit === 'tranche') {
    return Math.max(1, Math.round(amount));
  }

  return 1;
}

function normalizeUnit(value) {
  const raw = cleanString(value).toLowerCase();

  if (['g', 'gramme', 'grammes'].includes(raw)) return { unit: 'g', isRecognized: true };
  if (['kg', 'kilo', 'kilos', 'kilogramme', 'kilogrammes'].includes(raw)) return { unit: 'kg', isRecognized: true };
  if (['ml', 'millilitre', 'millilitres'].includes(raw)) return { unit: 'ml', isRecognized: true };
  if (['cl', 'centilitre', 'centilitres'].includes(raw)) return { unit: 'cl', isRecognized: true };
  if (['l', 'litre', 'litres'].includes(raw)) return { unit: 'l', isRecognized: true };
  if (['tranche', 'tranches'].includes(raw)) return { unit: 'tranche', isRecognized: true };
  if (['unité', 'unites', 'unités', 'unite', 'pièce', 'piece', 'pièces', 'pieces'].includes(raw)) {
    return { unit: 'unité', isRecognized: true };
  }

  return { unit: 'unité', isRecognized: false };
}

function normalizeCategory(value) {
  const raw = cleanString(value).toLowerCase();
  const allowed = new Set(['dairy', 'produce', 'meat', 'other']);
  return allowed.has(raw) ? raw : 'other';
}

function normalizeStorageLocation(value, productName = '') {
  const name = normalizeStorageText(productName);

  const rules = [
    {
      location: 'freezer',
      pattern: /\b(glaces?|cremes? glacees?|surgele(?:e|s|es)?|frozen|bac de glace)\b/,
    },
    {
      location: 'pantry',
      pattern: /\b(pates?|riz|farine|sucre|conserves?|biscuits?|chips|pains? au chocolat|cereales?)\b/,
    },
    {
      location: 'spices',
      pattern: /\b(sel|poivre|paprika|curry|herbes?|epices?|bouillons?)\b/,
    },
    {
      location: 'fridge',
      pattern: /\b(jambon|viandes?|poissons?|lait|yaourts?|fromages?|beurre|creme|salade fraiche)\b/,
    },
  ];

  for (const rule of rules) {
    if (rule.pattern.test(name)) return rule.location;
  }

  const normalizedValue = cleanString(value).toLowerCase();
  const allowed = new Set(['fridge', 'pantry', 'freezer', 'spices']);
  return allowed.has(normalizedValue) ? normalizedValue : 'fridge';
}

function normalizeStorageText(value) {
  return cleanString(value)
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '');
}

function jsonResponse(statusCode, body) {
  return {
    statusCode,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
    },
    body: JSON.stringify(body),
  };
}

exports.normalizeStorageLocation = normalizeStorageLocation;
