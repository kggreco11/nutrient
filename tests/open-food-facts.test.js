import test from 'node:test';
import assert from 'node:assert/strict';
import {productToFood} from '../app/open-food-facts.js';
test('barcode data converts standardized grams into displayed micronutrient units',()=>{const f=productToFood({product_name:'Test cereal',nutriments:{'energy-kcal_100g':350,proteins_100g:10,'calcium_100g':.12,'vitamin-b12_100g':.0000024}},'12345678');assert.equal(f.calories,350);assert.equal(f.values.protein,10);assert.equal(f.values.calcium,120);assert.equal(f.values.b12,2.4);assert.equal(f.values.vitD,null);assert.equal(f.source,'Open Food Facts');});
test('barcode data preserves explicit zero, rejects malformed values and supports kJ',()=>{const f=productToFood({product_name:'Test',nutriments:{energy_100g:418.4,fiber_100g:0,iron_100g:-1}},'12345678');assert.equal(f.calories,100);assert.equal(f.values.fiber,0);assert.equal(f.values.iron,null);});
test('barcode products without usable calorie information are rejected',()=>{assert.throws(()=>productToFood({product_name:'Missing',nutriments:{}},'12345678'));});
