import assert from 'node:assert/strict';
import { test } from 'node:test';
import { parseBoundedLimit } from '../lib/http-query.js';

test('parseBoundedLimit falls back for invalid values', () => {
  assert.equal(parseBoundedLimit(undefined, { defaultValue: 30 }), 30);
  assert.equal(parseBoundedLimit('', { defaultValue: 30 }), 30);
  assert.equal(parseBoundedLimit('abc', { defaultValue: 30 }), 30);
  assert.equal(parseBoundedLimit(Number.NaN, { defaultValue: 30 }), 30);
});

test('parseBoundedLimit clamps and truncates numeric values', () => {
  assert.equal(parseBoundedLimit('-5', { defaultValue: 30, min: 1, max: 100 }), 1);
  assert.equal(parseBoundedLimit('12.8', { defaultValue: 30, min: 1, max: 100 }), 12);
  assert.equal(parseBoundedLimit('999', { defaultValue: 30, min: 1, max: 100 }), 100);
});

test('parseBoundedLimit sanitizes invalid option values', () => {
  assert.equal(parseBoundedLimit('bad', { defaultValue: Number.NaN, min: 5, max: 100 }), 5);
  assert.equal(parseBoundedLimit('50', { defaultValue: 30, min: 10, max: 5 }), 10);
  assert.equal(parseBoundedLimit('4', { defaultValue: 30, min: 'bad', max: 'bad' }), 4);
});
