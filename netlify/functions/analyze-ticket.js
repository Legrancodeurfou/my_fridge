const MODEL = process.env.GEMINI_MODEL || 'gemini-3.1-flash-lite';

const PROMPT = `
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
`;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: '',
    };
  }

  if (event.httpMethod !== 'POST') {
    return jsonResponse(405, { error: 'Method not allowed' });
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    return jsonResponse(500, {
      error: 'GEMINI_API_KEY is missing in Netlify environment variables.',
    });
  }

  let payload;
  try {
    payload = JSON.parse(event.body || '{}');
  } catch (_) {
    return jsonResponse(400, { error: 'Invalid JSON body.' });
  }

  const imageBase64 = payload.imageBase64;
  const mimeType = payload.mimeType || 'image/jpeg';

  if (!imageBase64 || typeof imageBase64 !== 'string') {
    return jsonResponse(400, { error: 'imageBase64 is required.' });
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
    return jsonResponse(500, {
      error: error.message || 'Gemini analysis failed.',
    });
  }
};

async function callGemini({ apiKey, imageBase64, mimeType }) {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${apiKey}`;

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
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
        temperature: 0.1,
        response_mime_type: 'application/json',
      },
    }),
  });

  const text = await response.text();

  if (!response.ok) {
    throw new Error(`Gemini API error ${response.status}: ${text}`);
  }

  return JSON.parse(text);
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
  const name = cleanString(raw.name);
  if (!name) return null;

  const unit = normalizeUnit(raw.unit);
  const amount = toPositiveNumber(raw.amount, toPositiveNumber(raw.quantity, 1));
  const quantity = normalizeQuantity(raw.quantity, amount, unit);
  const category = normalizeCategory(raw.category);
  const shelfLifeDays = normalizeShelfLifeDays(
    raw.estimatedShelfLifeDays,
    category,
  );

  const expirationDate = new Date(today);
  expirationDate.setDate(expirationDate.getDate() + shelfLifeDays);

  return {
    name,
    quantity,
    amount,
    unit,
    category,
    estimatedExpirationDate: expirationDate.toISOString(),
  };
}

function cleanString(value) {
  if (typeof value !== 'string') return '';
  return value.trim().replace(/\s+/g, ' ');
}

function toPositiveNumber(value, fallback) {
  const number = Number(value);
  return Number.isFinite(number) && number > 0 ? number : fallback;
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

  if (['g', 'gramme', 'grammes'].includes(raw)) return 'g';
  if (['kg', 'kilo', 'kilos', 'kilogramme', 'kilogrammes'].includes(raw)) return 'kg';
  if (['ml', 'millilitre', 'millilitres'].includes(raw)) return 'ml';
  if (['cl', 'centilitre', 'centilitres'].includes(raw)) return 'cl';
  if (['l', 'litre', 'litres'].includes(raw)) return 'l';
  if (['tranche', 'tranches'].includes(raw)) return 'tranche';
  if (['unité', 'unites', 'unités', 'piece', 'pièce', 'pieces', 'pièces'].includes(raw)) {
    return 'unité';
  }

  return 'unité';
}

function normalizeCategory(value) {
  const raw = cleanString(value).toLowerCase();
  const allowed = new Set(['dairy', 'produce', 'meat', 'other']);
  return allowed.has(raw) ? raw : 'other';
}

function normalizeShelfLifeDays(value, category) {
  const number = Number(value);

  if (Number.isFinite(number) && number >= 1 && number <= 730) {
    return Math.round(number);
  }

  if (category === 'meat') return 3;
  if (category === 'produce') return 5;
  if (category === 'dairy') return 10;
  return 30;
}

function jsonResponse(statusCode, body) {
  return {
    statusCode,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  };
}
