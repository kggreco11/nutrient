import { nutrients } from "./data.js";
export const foodKind = (food) => food.kind || "food";
export function combineFoods(name, items, id) {
  if (!name.trim() || !items.length)
    throw Error("Give the meal a name and add at least one ingredient.");
  if (
    items.some(
      (x) =>
        !x.food ||
        !Number.isFinite(x.quantity) ||
        x.quantity <= 0 ||
        x.quantity > 100,
    )
  )
    throw Error("Use a serving quantity between 0 and 100.");
  const values = {},
    partialNutrients = [];
  for (const n of nutrients) {
    const known = items.filter((x) => x.food.values[n.id] != null);
    values[n.id] = known.length
      ? known.reduce((sum, x) => sum + x.food.values[n.id] * x.quantity, 0)
      : null;
    if (
      known.length !== items.length ||
      items.some((x) => x.food.partialNutrients?.includes(n.id))
    )
      partialNutrients.push(n.id);
  }
  return {
    id,
    name: name.trim(),
    kind: "meal",
    serving: "1 saved meal",
    emoji: "◈",
    calories: items.reduce((sum, x) => sum + x.food.calories * x.quantity, 0),
    values,
    partialNutrients,
    source: "Saved meal",
    components: items.map(({ food, quantity }) => ({
      name: food.name,
      foodId: food.id,
      quantity,
      serving: food.serving,
      source: food.source || "Custom label",
      sourceUrl: food.sourceUrl || null,
    })),
  };
}
export function sourceLabel(food) {
  return (
    food.source ||
    (food.id.startsWith("custom-") ? "Custom label" : "Sample values")
  );
}
