const PRODUCT_RULES = [
  {
    days: 52,
    terms: [
      'roquefort',
      'fromage bleu',
      "bleu d'auvergne",
      'bleu d auvergne',
      'gorgonzola',
      'stilton',
      'fourme',
    ],
  },
  {
    days: 40,
    terms: [
      'leerdammer',
      'emmental',
      'gruyere',
      'comte',
      'gouda',
      'edam',
      'cheddar',
      'parmesan',
      'fromage sous vide',
      'fromage emballe',
    ],
  },
  { days: 52, terms: ['beurre'] },
  {
    days: 14,
    terms: ['jambon', 'charcuterie', 'saucisson', 'prosciutto', 'lardons'],
  },
  { days: 120, terms: ['lait uht'] },
  { days: 9, terms: ['lait frais', 'lait'] },
  { days: 25, terms: ['yaourt', 'yaourts', 'yogourt', 'yogourts'] },
  {
    days: 10,
    terms: ['mozzarella', 'fromage blanc', 'ricotta', 'chevre frais'],
  },
  {
    days: 4,
    terms: [
      'salade',
      'laitue',
      'roquette',
      'epinard',
      'tomate',
      'courgette',
      'concombre',
      'avocat',
      'legume frais',
      'legumes frais',
    ],
  },
  {
    days: 7,
    terms: [
      'pomme',
      'poire',
      'banane',
      'orange',
      'mandarine',
      'clementine',
      'peche',
      'abricot',
      'raisin',
      'fraise',
      'framboise',
      'fruit frais',
      'fruits frais',
    ],
  },
  {
    days: 365,
    terms: [
      'pates',
      'spaghetti',
      'spaghettis',
      'macaroni',
      'riz',
      'conserve',
      'conserves',
      'boite de conserve',
      'thon en boite',
      'mais en boite',
      'haricot en boite',
    ],
  },
  {
    days: 270,
    terms: [
      'chips',
      'biscuit',
      'biscuits',
      'gateau sec',
      'gateaux secs',
      'cracker',
      'crackers',
      'aperitif',
    ],
  },
  {
    days: 540,
    terms: [
      'epice',
      'epices',
      'poivre',
      'paprika',
      'cumin',
      'curcuma',
      'cannelle',
      'herbes de provence',
    ],
  },
  { days: 4, terms: ['pain', 'baguette'] },
  { days: 21, terms: ['oeuf', 'oeufs'] },
];

function normalizeShelfLifeDays(value, category, name) {
  const normalizedName = normalizeText(name);
  const productRule = PRODUCT_RULES.find((rule) =>
    rule.terms.some((term) => containsTerm(normalizedName, term)),
  );

  if (productRule) {
    return productRule.days;
  }

  const fallbackDays = fallbackDaysForCategory(category);
  const number = Number(value);

  if (Number.isFinite(number) && number >= 1 && number <= 730) {
    return Math.max(fallbackDays, Math.round(number));
  }

  return fallbackDays;
}

function fallbackDaysForCategory(category) {
  if (category === 'meat') return 7;
  if (category === 'produce') return 7;
  if (category === 'dairy') return 14;
  return 30;
}

function normalizeText(value) {
  if (typeof value !== 'string') return '';

  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/œ/g, 'oe')
    .toLowerCase();
}

function containsTerm(value, term) {
  const escapedTerm = term.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return new RegExp(`(^|[^a-z0-9])${escapedTerm}($|[^a-z0-9])`).test(value);
}

module.exports = {
  normalizeShelfLifeDays,
};
