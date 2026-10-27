let databasePromise;
export function loadFoodDatabase() {
  return (databasePromise ??= fetch(
    import.meta.env.BASE_URL + "data/usda-sr-legacy.json",
  )
    .then((r) => {
      if (!r.ok)
        throw Error(
          "The offline food database could not be loaded. Please retry.",
        );
      return r.json();
    })
    .catch((e) => {
      databasePromise = null;
      throw e;
    }));
}
export function searchDatabase(
  foods,
  query,
  { restaurantOnly = false, limit = 45 } = {},
) {
  const words = (text) =>
    text
      .toLowerCase()
      .normalize("NFKD")
      .replace(/[’']/g, "")
      .split(/[^a-z0-9]+/)
      .filter(Boolean)
      .map((t) => (t.length > 3 && t.endsWith("s") ? t.slice(0, -1) : t));
  const tokens = words(query);
  const processed = [
    "breaded",
    "sliced",
    "roll",
    "glazed",
    "tenders",
    "sandwich",
  ];
  return foods
    .filter(
      (f) =>
        (!restaurantOnly || f.restaurant) &&
        tokens.every((t) => words(f.name).some((w) => w.startsWith(t))),
    )
    .map((f) => ({
      food: f,
      rank:
        (words(f.name.split("(")[0]).join(" ") === tokens.join(" ")
          ? -100
          : 0) +
        f.name.length * 0.12 +
        (f.id.startsWith("usda-") ? 30 : 0) -
        tokens.filter((t) => words(f.name).includes(t)).length * 15 +
        processed.filter(
          (w) =>
            words(f.name).includes(w) && !tokens.some((t) => w.startsWith(t)),
        ).length *
          25,
    }))
    .sort((a, b) => a.rank - b.rank)
    .slice(0, limit)
    .map((x) => x.food);
}
