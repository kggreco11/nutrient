import test from 'node:test';
import assert from 'node:assert/strict';
import { readLabel, validateLabel } from '../server/label.js';
import { handleApi } from '../server/http.js';

test('label extraction uses the selected Flash model with no price cap and separates untrusted OCR', async () => {
  const text = 'Nutrition Facts\nServing size 2/3 cup (55 g)\nCalories 230\nProtein 3g\nSodium 160mg';
  const result = await readLabel({ text, apiKey: 'test', fetchImpl: async (_, init) => {
    const body = JSON.parse(init.body);
    assert.equal(body.model, 'deepseek/deepseek-v4.1-flash');
    assert.equal(body.provider.max_price, undefined);
    assert.equal(body.messages[1].content, text);
    assert.match(body.messages[0].content, /percent daily values/);
    assert.match(body.messages[0].content, /per-serving/);
    assert.equal(body.tools, undefined);
    assert.equal(body.response_format.type, 'json_schema');
    assert.equal(body.response_format.json_schema.strict, true);
    return Response.json({ choices: [{ message: { content: JSON.stringify({ name: '', serving: '2/3 cup (55 g)', calories: 230, values: { protein: 3, sodium: 160, fat: 0 } }) } }] });
  }});
  assert.equal(result.label.values.protein, 3);
  assert.equal(result.label.values.sodium, 160);
  assert.equal(result.label.values.fat, 0);
  assert.equal(result.label.values.chromium, null);
  assert.equal(result.label.serving, '2/3 cup (55 g)');
});
test('label validation retains missing calories and rejects invented schema fields and malformed amounts', () => {
  const label = validateLabel({ name: 'Nutrition Facts', serving: '1 cup', values: { calcium: 300, protein: '8', sodium: -1, b12: Infinity, madeUp: 50 } });
  assert.equal(label.name, '');
  assert.equal(label.calories, null);
  assert.equal(label.values.protein, null);
  assert.equal(label.values.sodium, null);
  assert.equal(label.values.b12, null);
  assert.equal(label.values.madeUp, undefined);
  assert.throws(() => validateLabel({ values: {} }), /No nutrition/);
});
test('label route requires authentication before model execution', async () => {
  const response = await handleApi(new Request('https://app.example/api/label', { method: 'POST', body: JSON.stringify({ text: 'Nutrition Facts' }) }), {}, async () => []);
  assert.equal(response.status, 401);
});
test('blank, oversized, or invalid model responses never become foods', async () => {
  const base = { apiKey: 'test', fetchImpl: async () => Response.json({choices:[{message:{content:'not JSON'}}]}) };
  await assert.rejects(readLabel({ ...base, text: '' }), /Photograph/);
  await assert.rejects(readLabel({ ...base, text: 'a'.repeat(24001) }), /Photograph/);
  await assert.rejects(readLabel({ ...base, text: 'Nutrition Facts unreadable label' }), /clearer photo/);
});
