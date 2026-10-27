import { nutrients, foods, defaultTargets } from "./data.js";
export function totals(entries, catalog = foods) {
  const result = {
    calories: 0,
    ...Object.fromEntries(nutrients.map((n) => [n.id, 0])),
  };
  for (const entry of entries) {
    const food = catalog.find((f) => f.id === entry.foodId);
    if (!food || !Number.isFinite(entry.quantity) || entry.quantity <= 0)
      continue;
    result.calories += food.calories * entry.quantity;
    for (const n of nutrients)
      result[n.id] += (food.values[n.id] ?? 0) * entry.quantity;
  }
  return result;
}
export function coverage(value, target) {
  return target > 0 ? Math.min(100, Math.max(0, (value / target) * 100)) : 0;
}
export function score(values, targets = defaultTargets, group) {
  const list = nutrients.filter(
    (n) => n.group !== "Macros" && (!group || n.group === group),
  );
  return Math.round(
    list.reduce(
      (sum, n) => sum + coverage(values[n.id] ?? 0, targets[n.id]),
      0,
    ) / list.length,
  );
}
export function status(percent) {
  return percent >= 100
    ? "Target met"
    : percent >= 70
      ? "Getting there"
      : "Room to grow";
}
export function validState(s) {
  if (
    !s ||
    s.version !== 1 ||
    !s.days ||
    typeof s.days !== "object" ||
    Array.isArray(s.days) ||
    !Array.isArray(s.customFoods) ||
    !s.targets
  )
    return false;
  if (
    !nutrients.every(
      (n) =>
        Number.isFinite(s.targets[n.id]) &&
        s.targets[n.id] > 0 &&
        s.targets[n.id] <= 100000,
    )
  )
    return false;
  if (
    !Number.isFinite(s.calorieTarget) ||
    s.calorieTarget <= 0 ||
    !Number.isInteger(s.waterTarget) ||
    s.waterTarget < 1 ||
    s.waterTarget > 30
  )
    return false;
  if (
    !s.customFoods.every(
      (f) =>
        f &&
        typeof f.id === "string" &&
        (!f.kind || ["food", "meal", "supplement"].includes(f.kind)) &&
        (f.archived === undefined || typeof f.archived === "boolean") &&
        (!f.partialNutrients ||
          (Array.isArray(f.partialNutrients) &&
            f.partialNutrients.every((id) =>
              nutrients.some((n) => n.id === id),
            ))) &&
        (!f.components ||
          (Array.isArray(f.components) &&
            f.components.every(
              (c) =>
                c &&
                typeof c.name === "string" &&
                typeof c.source === "string" &&
                typeof c.serving === "string" &&
                Number.isFinite(c.quantity) &&
                c.quantity > 0,
            ))) &&
        typeof f.name === "string" &&
        typeof f.serving === "string" &&
        Number.isFinite(f.calories) &&
        f.calories >= 0 &&
        f.values &&
        nutrients.every(
          (n) =>
            f.values[n.id] === null ||
            (Number.isFinite(f.values[n.id]) && f.values[n.id] >= 0),
        ),
    )
  )
    return false;
  const ids = new Set([...foods, ...s.customFoods].map((f) => f.id));
  return Object.entries(s.days).every(
    ([date, day]) =>
      /^\d{4}-\d{2}-\d{2}$/.test(date) &&
      day &&
      Number.isInteger(day.water) &&
      day.water >= 0 &&
      day.water <= 30 &&
      Array.isArray(day.entries) &&
      day.entries.every(
        (e) =>
          e &&
          typeof e.id === "string" &&
          ids.has(e.foodId) &&
          ["Breakfast", "Lunch", "Dinner", "Snacks", "Supplements"].includes(
            e.meal,
          ) &&
          Number.isFinite(e.quantity) &&
          e.quantity > 0 &&
          e.quantity <= 100,
      ),
  );
}
