const test = require('node:test');
const assert = require('node:assert/strict');

const {
  normalizeCategory,
  normalizeProduct,
  suggestUnit,
} = require('../netlify/functions/analyze-ticket');

test('suggests prudent units from product names', () => {
  assert.equal(suggestUnit('Jambon blanc'), 'tranche');
  assert.equal(suggestUnit('Œufs frais'), 'unité');
  assert.equal(suggestUnit('Lait demi-écrémé'), 'l');
  assert.equal(suggestUnit('Pâtes', true), 'g');
  assert.equal(suggestUnit('Chips nature'), 'paquet');
  assert.equal(suggestUnit('Poivre noir'), 'pot');
  assert.equal(suggestUnit('Produit inconnu'), 'unité');
});

test('keeps an explicit valid unit from the ticket', () => {
  const product = normalizeProduct(
    {
      name: 'Jambon blanc',
      quantity: 1,
      amount: 200,
      unit: 'g',
      category: 'meat',
      estimatedShelfLifeDays: 14,
    },
    new Date('2026-06-11T00:00:00.000Z'),
  );

  assert.equal(product.unit, 'g');
  assert.equal(product.amount, 200);
});

test('keeps a detected amount when inferring a compatible unit', () => {
  const product = normalizeProduct(
    {
      name: 'Pâtes complètes',
      quantity: 1,
      amount: 500,
      unit: '',
      category: 'starches',
      estimatedShelfLifeDays: 365,
    },
    new Date('2026-06-11T00:00:00.000Z'),
  );

  assert.equal(product.unit, 'g');
  assert.equal(product.amount, 500);
});

test('normalizes enriched categories and falls back to other', () => {
  assert.equal(normalizeCategory('other', 'Saumon fumé'), 'seafood');
  assert.equal(normalizeCategory('other', 'Pâtes complètes'), 'starches');
  assert.equal(
    normalizeCategory('other', 'Poivre noir'),
    'spicesCondiments',
  );
  assert.equal(normalizeCategory('unknown', 'Produit ambigu'), 'other');
});
