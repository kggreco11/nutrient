import test from "node:test";
import assert from "node:assert/strict";
import { initialState, nutrients } from "../app/data.js";
import {
  migratePersonalTargets,
  personalSupplements,
} from "../app/personal-plan.js";
test("personal targets replace legacy defaults once while preserving custom values and diary", () => {
  const state = initialState();
  delete state.personalTargetVersion;
  state.calorieTarget = 2200;
  Object.assign(state.targets, {
    protein: 100,
    carbs: 275,
    fat: 78,
    b6: 1.3,
    b12: 2.4,
    vitD: 50,
  });
  const days = JSON.stringify(state.days);
  const library = state.customFoods.length;
  assert.equal(
    migratePersonalTargets(state, personalSupplements(nutrients)),
    true,
  );
  assert.equal(state.calorieTarget, 3500);
  assert.equal(state.targets.protein, 160);
  assert.equal(state.targets.carbs, 500);
  assert.equal(state.targets.fat, 95);
  assert.equal(state.targets.b6, 1.8);
  assert.equal(state.targets.b12, 4);
  assert.equal(state.targets.vitD, 50);
  assert.equal(JSON.stringify(state.days), days);
  assert.equal(state.customFoods.length, library);
  state.targets.protein = 170;
  assert.equal(migratePersonalTargets(state), false);
  assert.equal(state.targets.protein, 170);
});
test("reported supplement doses are per actual daily dose and are never automatically logged", () => {
  const state = initialState();
  assert.equal(state.targets.vitD, 25);
  const d = state.customFoods.find((f) => f.id === "personal-d3-k2");
  assert.equal(d.values.vitD, 25);
  assert.equal(d.values.vitK, 45);
  assert.equal(d.energyUnreported, true);
  const fish = state.customFoods.find(
    (f) => f.id === "personal-nordic-ultimate-omega",
  );
  assert.equal(fish.values.omega3, 0.64);
  assert.equal(fish.values.fat, 1);
  assert.equal(fish.calories, 10);
  assert.ok(
    Object.values(state.days).every((day) =>
      day.entries.every(
        (entry) => entry.foodId !== d.id && entry.foodId !== fish.id,
      ),
    ),
  );
});
