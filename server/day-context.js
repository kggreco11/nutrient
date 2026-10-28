import { nutrients } from "../app/data.js";
const finite = (n) => typeof n === "number" && Number.isFinite(n) && n >= 0;
const invalid = () =>
  Object.assign(Error("Invalid selected-day nutrition context."), {
    status: 400,
  });
export function summarizeDay(input) {
  if (input == null) return null;
  if (
    !/^\d{4}-\d{2}-\d{2}$/.test(input.date) ||
    !finite(input.calorieTarget) ||
    input.calorieTarget <= 0 ||
    input.calorieTarget > 20000 ||
    !Array.isArray(input.entries) ||
    input.entries.length > 500 ||
    !nutrients.every(
      (n) =>
        finite(input.targets?.[n.id]) &&
        input.targets[n.id] > 0 &&
        input.targets[n.id] <= 100000,
    )
  )
    throw invalid();
  for (const e of input.entries)
    if (
      !finite(e.quantity) ||
      e.quantity <= 0 ||
      e.quantity > 100 ||
      !finite(e.food?.calories) ||
      e.food.calories > 100000 ||
      !e.food.values ||
      (e.food.partialNutrients != null &&
        (!Array.isArray(e.food.partialNutrients) ||
          e.food.partialNutrients.some(
            (id) => !nutrients.some((n) => n.id === id),
          ))) ||
      !nutrients.every(
        (n) =>
          e.food.values[n.id] == null ||
          (finite(e.food.values[n.id]) && e.food.values[n.id] <= 100000),
      )
    )
      throw invalid();
  const consumed = input.entries.reduce(
    (sum, e) => sum + e.food.calories * e.quantity,
    0,
  );
  return {
    date: input.date,
    loggedEntries: input.entries.length,
    calories: {
      consumed,
      target: input.calorieTarget,
      remaining: Math.max(0, input.calorieTarget - consumed),
      partial: input.entries.some((e) => e.food.energyUnreported === true),
    },
    nutrients: nutrients.map((n) => {
      const known = input.entries.filter((e) => e.food.values[n.id] != null);
      const value = known.reduce(
        (sum, e) => sum + e.food.values[n.id] * e.quantity,
        0,
      );
      const target = input.targets[n.id];
      return {
        id: n.id,
        name: n.name,
        unit: n.unit,
        consumed: known.length ? value : null,
        target,
        remaining: known.length ? Math.max(0, target - value) : null,
        status: !known.length
          ? "unreported"
          : value >= target
            ? "met"
            : "below",
        partial:
          known.length > 0 &&
          (known.length < input.entries.length ||
            input.entries.some((e) => e.food.partialNutrients?.includes(n.id))),
      };
    }),
  };
}
export function evaluateChoices(choices, records, summary) {
  if (!summary)
    throw Error(
      "The selected diary day is not available. Ask the user to open the day they want to discuss.",
    );
  if (!Array.isArray(choices) || !choices.length || choices.length > 6)
    throw Error("Compare one to six food options.");
  return choices.map((c) => {
    const food = records.get(c.foodId);
    if (!food || food.kind === "supplement")
      throw Error(
        "Search for this food first; food suggestions do not include supplement dosing.",
      );
    if (!finite(c.quantity) || c.quantity <= 0 || c.quantity > 100)
      throw Error("Use a valid serving multiplier.");
    const calories = food.calories * c.quantity;
    return {
      foodId: food.id,
      name: food.name,
      source: food.source,
      serving: food.serving,
      quantity: c.quantity,
      calories,
      caloriesRemainingAfter: summary.calories.remaining - calories,
      nutrients: summary.nutrients
        .filter((n) => n.status === "below")
        .map((n) => {
          const amount = food.values[n.id];
          return {
            id: n.id,
            unit: n.unit,
            contribution: amount == null ? null : amount * c.quantity,
            remainingBefore: n.remaining,
            remainingAfter:
              n.remaining == null || amount == null
                ? null
                : Math.max(0, n.remaining - amount * c.quantity),
            partial:
              n.partial || food.partialNutrients?.includes(n.id) === true,
          };
        }),
    };
  });
}
