import test from 'node:test';
import assert from 'node:assert/strict';
import { passages } from '../Assets/search-results.js';

const result = {
  url: '/episodes/S01E1-example/',
  content: 'Example title First passage about state. Next passage about layout. Another state example.',
  locations: [5, 9, 11],
  weighted_locations: [{ location: 5, balanced_score: 1 }, { location: 9, balanced_score: 9 }, { location: 11, balanced_score: 1 }],
  anchors: [{ id: 'main', location: 0 }, { id: 't-6', location: 2 }, { id: 't-65', location: 6 }, { id: 't-65-2', location: 10 }],
};

test('passages rank the matching cue and stay within its boundaries', () => {
  const found = passages(result);
  assert.equal(found.length, 2);
  assert.equal(found[0].href, '/episodes/S01E1-example/?t=65#t-65');
  assert.equal(found[0].time, '1:05');
  assert.equal(found[0].excerpt, 'Next passage about <mark>layout.</mark>');
  assert.equal(found[1].href, '/episodes/S01E1-example/?t=6#t-6');
});

test('duplicate timestamps preserve the anchor identifying the exact passage', () => {
  const found = passages({ ...result, locations: [11] });
  assert.equal(found[0].href, '/episodes/S01E1-example/?t=65#t-65-2');
});

test('code and authored HTML are escaped before marking matched words', () => {
  const found = passages({
    ...result, content: '<script>alert(1)</script> a < b && c', locations: [0, 2],
    anchors: [{ id: 't-0', location: 0 }],
  });
  assert.equal(found[0].excerpt, '<mark>&lt;script&gt;alert(1)&lt;/script&gt;</mark> a <mark>&lt;</mark> b &amp;&amp; c');
});

test('title-only matches and transcripts without timestamps use the standard excerpt', () => {
  assert.deepEqual(passages({ ...result, locations: [0] }), []);
  assert.deepEqual(passages({ ...result, anchors: [] }), []);
});
