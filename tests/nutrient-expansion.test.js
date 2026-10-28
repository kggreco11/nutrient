import test from "node:test";
import assert from "node:assert/strict";
import { nutrients, initialState, foods } from "../app/data.js";
import { migrateReferenceTargets } from "../app/targets.js";
import { validState } from "../app/model.js";
test("expanded nutrient catalog includes the missing vitamins and trace minerals", () => {
  for (const id of [
    "b3",
    "b5",
    "biotin",
    "choline",
    "phosphorus",
    "sodium",
    "chloride",
    "copper",
    "iodine",
    "manganese",
    "molybdenum",
    "chromium",
    "fluoride",
  ])
    assert.ok(
      nutrients.some((n) => n.id === id),
      `Missing ${id}`,
    );
});
test("older backups gain targets and unknown fields without losing diary or customized goals", () => {
  const s = initialState();
  s.referenceTargetVersion = 1;
  s.targets.vitD = 50;
  const history = JSON.stringify(s.days);
  for (const id of ["chromium", "choline", "b3"]) {
    delete s.targets[id];
  }
  const f = {
    id: "old-custom",
    name: "Old breakfast",
    serving: "1 serving",
    calories: 100,
    values: { ...foods[0].values, protein: 8 },
    kind: "food",
  };
  s.customFoods = [f];
  for (const id of ["chromium", "choline", "b3"]) delete f.values[id];
  migrateReferenceTargets(s);
  assert.equal(s.targets.chromium, 35);
  assert.equal(s.targets.choline, 550);
  assert.equal(s.targets.vitD, 50);
  assert.equal(f.values.chromium, null);
  assert.equal(f.values.protein, 8);
  assert.equal(JSON.stringify(s.days), history);
  assert.ok(validState(s));
});
