import test from "node:test";
import assert from "node:assert/strict";
import { initialState, nutrients } from "../app/data.js";
import { migrateReferenceTargets } from "../app/targets.js";
import { nutrientPatterns } from "../app/trends.js";
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
test("recorded shortfall patterns distinguish complete, partial, and entirely unknown days", () => {
  const s = initialState();
  const food = (id, value, partial = false) => ({
    id,
    calories: 0,
    values: Object.fromEntries(
      nutrients.map((n) => [n.id, n.id === "vitD" ? value : null]),
    ),
    partialNutrients: partial ? ["vitD"] : [],
  });
  const catalog = [
    food("known", 5),
    food("unknown", null),
    food("partial", 5, true),
  ];
  const day = (ids) => ({
    water: 0,
    entries: ids.map((foodId, i) => ({
      id: "real-" + i,
      foodId,
      quantity: 1,
      meal: "Breakfast",
    })),
  });
  s.days = {
    "2026-10-01": day(["known"]),
    "2026-10-02": day(["known", "unknown"]),
    "2026-10-03": day(["partial"]),
    "2026-10-04": day(["unknown"]),
  };
  const record = nutrientPatterns(s, catalog, "2026-10-27", 3).below.find(
    (n) => n.id === "vitD",
  );
  assert.equal(record.knownDays, 3);
  assert.equal(record.completeDays, 1);
  assert.equal(record.unreportedDays, 1);
  assert.equal(record.below, 3);
  assert.ok(Math.abs(record.average - 100 / 3) < 1e-9);
});
