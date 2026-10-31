import test from "node:test";
import assert from "node:assert/strict";
import { initialState, nutrients } from "../shared/data.js";
import { migrateReferenceTargets } from "../shared/targets.js";
test("legacy target migration preserves custom treatment targets, macros, history and repeated edits", () => {
  const s = initialState();
  Object.assign(s.targets, {
    calcium: 1300,
    iron: 18,
    magnesium: 420,
    potassium: 4700,
    b6: 1.7,
    vitD: 50,
    protein: 160,
  });
  const days = JSON.stringify(s.days);
  assert.equal(migrateReferenceTargets(s), true);
  assert.equal(s.targets.calcium, 1000);
  assert.equal(s.targets.iron, 8);
  assert.equal(s.targets.magnesium, 400);
  assert.equal(s.targets.potassium, 3400);
  assert.equal(s.targets.b6, 1.3);
  assert.equal(s.targets.vitD, 50);
  assert.equal(s.targets.protein, 160);
  assert.equal(JSON.stringify(s.days), days);
  s.targets.iron = 12;
  assert.equal(migrateReferenceTargets(s), false);
  assert.equal(s.targets.iron, 12);
});
