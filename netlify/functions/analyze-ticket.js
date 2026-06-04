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

function normalizeShelfLifeDays(value, category, name) {
  const number = Number(value);

  if (Number.isFinite(number) && number >= 1 && number <= 730) {
    return Math.round(number);
  }

  const lowerName = name.toLowerCase();

  if (lowerName.includes('viande') || lowerName.includes('poulet') || lowerName.includes('steak') || lowerName.includes('jambon')) return 3;
  if (lowerName.includes('salade') || lowerName.includes('tomate') || lowerName.includes('courgette') || lowerName.includes('avocat')) return 5;
  if (lowerName.includes('lait') || lowerName.includes('yaourt') || lowerName.includes('crème') || lowerName.includes('fromage') || lowerName.includes('mozzarella')) return 10;
  if (lowerName.includes('pain') || lowerName.includes('baguette')) return 4;
  if (lowerName.includes('œuf') || lowerName.includes('oeuf')) return 14;

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
