import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { nutrients } from "../shared/data.js";
import { searchDatabase } from "../shared/food-database.js";
const database = JSON.parse(
  readFileSync(new URL("../data/usda-sr-legacy.json", import.meta.url)),
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
  assert.ok(database.filter((f) => f.portions?.length).length > 7500);
  assert.ok(
    database.every(
      (f) =>
        f.servingGrams === 100 &&
        f.portions.every(
          (p) =>
            typeof p.label === "string" &&
            p.grams > 0 &&
            Number.isFinite(p.grams),
        ),
    ),
  );
  const milk = database.find(
    (f) => f.name === "Milk, whole, 3.25% milkfat, with added vitamin D",
  );
  assert.equal(milk.portions.find((p) => p.label === "cup").grams, 244);
  assert.equal(milk.portions.find((p) => p.label === "fl oz").grams, 30.5);
  assert.equal(milk.portions.find((p) => p.label === "tbsp").grams, 15);
});
