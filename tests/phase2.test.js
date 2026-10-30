import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { SYSTEM_PROMPT } from "../server/policy.js";
import { combineFoods } from "../app/library.js";
import { trendBuckets } from "../app/trends.js";
import { initialState, foods, nutrients } from "../app/data.js";
import { validState, totals, score } from "../app/model.js";
import { searchDatabase } from "../app/food-database.js";
const database = JSON.parse(
  readFileSync(new URL("../public/data/usda-sr-legacy.json", import.meta.url)),
);
test("bundled database contains actual USDA foods with historical fast-food coverage", () => {
  assert.equal(database.length, 7793);
  assert.equal(database.filter((f) => f.restaurant).length, 312);
  assert.ok(searchDatabase(database, "brown rice").length);
  assert.ok(searchDatabase(database, "subway").length);
  assert.ok(
    database.every((f) =>
      nutrients.every(
        (n) => f.values[n.id] === null || Number.isFinite(f.values[n.id]),
      ),
    ),
  );
});
test("meal snapshots retain known totals and mark partial fields", () => {
  const a = { ...foods[0], values: { ...foods[0].values, vitD: null } };
  const b = { ...foods[1], values: { ...foods[1].values, vitD: 2 } };
  const meal = combineFoods(
    "Breakfast",
    [
      { food: a, quantity: 2 },
      { food: b, quantity: 0.5 },
    ],
    "meal-test",
  );
  assert.equal(meal.calories, 350);
  assert.equal(meal.values.protein, 18.5);
  assert.equal(meal.values.vitD, 1);
  assert.ok(meal.partialNutrients.includes("vitD"));
  assert.equal(meal.components.length, 2);
  assert.throws(() => combineFoods("", [], "empty"));
});
test("supplements are valid diary entries and contribute to nutrient coverage", () => {
  const s = initialState(),
    f = {
      id: "supplement-test",
      kind: "supplement",
      name: "D test label",
      serving: "1 capsule",
      calories: 0,
      values: Object.fromEntries(
        nutrients.map((n) => [n.id, n.id === "vitD" ? 20 : null]),
      ),
    };
  s.customFoods.push(f);
  s.days["2026-10-20"] = {
    water: 0,
    entries: [
      { id: "supp-test-entry", foodId: f.id, meal: "Supplements", quantity: 1 },
    ],
  };
  assert.ok(validState(s));
  assert.equal(totals(s.days["2026-10-20"].entries, [f]).vitD, 20);
});
test("monthly trends exclude empty and sample entries and separate supplement contribution", () => {
  const s = initialState();
  s.days = {};
  const supplement = {
    id: "s",
    kind: "supplement",
    name: "Test",
    serving: "1 capsule",
    calories: 0,
    values: Object.fromEntries(nutrients.map((n) => [n.id, n.target])),
  };
  s.days["2026-09-02"] = {
    entries: [{ id: "real", foodId: "s", quantity: 1, meal: "Supplements" }],
    water: 0,
  };
  s.days["2026-09-03"] = {
    entries: [
      { id: "sample-1", foodId: "oats", quantity: 1, meal: "Breakfast" },
    ],
    water: 0,
    demo: true,
  };
  s.days["2026-10-01"] = { entries: [], water: 0 };
  const b = trendBuckets(s, [...foods, supplement], "2026-10-26", 3);
  assert.equal(b.length, 3);
  assert.equal(b[0].average, null);
  assert.equal(b[1].average, 100);
  assert.equal(b[1].foodOnly, 0);
  assert.equal(b[1].supplementDays, 1);
  assert.equal(b[1].loggedDays, 1);
  assert.equal(b[2].average, null);
});
test("month grouping handles year changes and excludes future dates", () => {
  const s = initialState();
  s.days = {
    "2026-12-01": {
      entries: [{ id: "x", foodId: "oats", quantity: 1, meal: "Breakfast" }],
      water: 0,
    },
    "2027-01-31": {
      entries: [
        { id: "future", foodId: "oats", quantity: 1, meal: "Breakfast" },
      ],
      water: 0,
    },
  };
  const b = trendBuckets(s, foods, "2027-01-20", 3);
  assert.deepEqual(
    b.map((x) => x.key),
    ["2026-11", "2026-12", "2027-01"],
  );
  assert.equal(b[1].loggedDays, 1);
  assert.equal(b[2].loggedDays, 0);
});
test("individual nutrient percentages preserve above-target values while collective score stays capped", () => {
  const s = initialState(),
    f = {
      id: "over",
      name: "test",
      serving: "1 dose",
      kind: "supplement",
      calories: 0,
      values: Object.fromEntries(nutrients.map((n) => [n.id, n.target * 2])),
    };
  s.days = {
    "2026-10-01": {
      water: 0,
      entries: [{ id: "real", foodId: f.id, meal: "Supplements", quantity: 1 }],
    },
  };
  assert.equal(trendBuckets(s, [f], "2026-10-26", 3, "vitD")[2].average, 200);
  assert.equal(trendBuckets(s, [f], "2026-10-26", 3, "score")[2].average, 100);
});
test("database keyword search does not mistake strawberries for a raw preparation", () => {
  assert.equal(
    searchDatabase(
      [{ id: "usda-1", name: "Oats with strawberries" }],
      "oats raw",
    ).length,
    0,
  );
  assert.equal(
    searchDatabase(
      [{ id: "usda-2", name: "McDONALD'S, Egg" }],
      "mcdonalds eggs",
    ).length,
    1,
  );
});
test("exact database food names rank ahead of derivative foods", () => {
  assert.match(searchDatabase(database, "oats")[0].name, /^Oats /);
});

test("USDA household portions keep food-specific gram weights", () => {
  assert.ok(database.filter(f => f.portions?.length).length > 7500);
  assert.ok(database.every(f => f.servingGrams === 100 && f.portions.every(p => typeof p.label === "string" && p.grams > 0 && Number.isFinite(p.grams))));
  const milk = database.find(f => f.name === "Milk, whole, 3.25% milkfat, with added vitamin D");
  assert.equal(milk.portions.find(p => p.label === "cup").grams, 244);
  assert.equal(milk.portions.find(p => p.label === "fl oz").grams, 30.5);
  assert.equal(milk.portions.find(p => p.label === "tbsp").grams, 15);
});
