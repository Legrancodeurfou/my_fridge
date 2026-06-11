const test = require('node:test');
const assert = require('node:assert/strict');

const {
  normalizeStorageLocation,
} = require('../netlify/functions/analyze-ticket');

test('suggests a storage location for clear product names', () => {
  assert.equal(normalizeStorageLocation('fridge', 'Glace vanille'), 'freezer');
  assert.equal(
    normalizeStorageLocation('fridge', 'Pains au chocolat'),
    'pantry',
  );
  assert.equal(normalizeStorageLocation('fridge', 'Poivre noir'), 'spices');
  assert.equal(normalizeStorageLocation('pantry', 'Jambon blanc'), 'fridge');
  assert.equal(normalizeStorageLocation('fridge', 'Chips nature'), 'pantry');
});

test('keeps valid suggestions and defaults unknown values to fridge', () => {
  assert.equal(normalizeStorageLocation('pantry', 'Produit sec'), 'pantry');
  assert.equal(normalizeStorageLocation('unknown', 'Produit ambigu'), 'fridge');
  assert.equal(normalizeStorageLocation(undefined, 'Produit ambigu'), 'fridge');
});
