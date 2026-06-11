const test = require('node:test');
const assert = require('node:assert/strict');

const {
  normalizeShelfLifeDays,
} = require('../netlify/functions/shelf-life-estimator');

test('uses realistic durations for common scanned products', () => {
  assert.equal(normalizeShelfLifeDays(3, 'meat', 'Jambon sous vide'), 14);
  assert.equal(normalizeShelfLifeDays(10, 'dairy', 'Roquefort'), 52);
  assert.equal(normalizeShelfLifeDays(10, 'dairy', 'Leerdammer'), 40);
  assert.equal(normalizeShelfLifeDays(10, 'dairy', 'Beurre doux'), 52);
  assert.equal(normalizeShelfLifeDays(5, 'other', 'Chips nature'), 270);
  assert.equal(normalizeShelfLifeDays(3, 'dairy', 'Lait frais'), 9);
  assert.equal(normalizeShelfLifeDays(10, 'dairy', 'Yaourts nature'), 25);
  assert.equal(normalizeShelfLifeDays(10, 'produce', 'Salade verte'), 4);
  assert.equal(normalizeShelfLifeDays(30, 'other', 'Pâtes'), 365);
  assert.equal(normalizeShelfLifeDays(30, 'other', 'Épices'), 540);
});

test('keeps a prudent fallback for ambiguous products', () => {
  assert.equal(normalizeShelfLifeDays(2, 'other', 'Produit alimentaire'), 30);
  assert.equal(normalizeShelfLifeDays(null, 'dairy', 'Produit laitier'), 14);
});
