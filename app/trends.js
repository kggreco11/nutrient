import { localDate, nutrients } from "./data.js";
import { score, totals, coverage } from "./model.js";
export function trendBuckets(
  state,
  catalog,
  endDate,
  months = 6,
  metric = "score",
) {
  const end = new Date(endDate + "T12:00:00");
  const start = new Date(end.getFullYear(), end.getMonth() - months + 1, 1, 12);
  return Array.from({ length: months }, (_, i) => {
    const d = new Date(start.getFullYear(), start.getMonth() + i, 1, 12),
      key = localDate(d).slice(0, 7);
    const days = Object.entries(state.days)
      .map(([date, day]) => [
        date,
        {
          ...day,
          entries: day.entries.filter((e) => !e.id.startsWith("sample-")),
        },
      ])
      .filter(
        ([date, day]) =>
          date.startsWith(key) &&
          date <= endDate &&
          day.entries.length &&
          (metric === "score" ||
            metric === "calories" ||
            day.entries.some(
              (e) =>
                catalog.find((f) => f.id === e.foodId)?.values[metric] != null,
            )),
      );
    const read = (entries) => {
      const t = totals(entries, catalog);
      return metric === "score"
        ? score(t, state.targets)
        : metric === "calories"
          ? t.calories
          : (t[metric] / state.targets[metric]) * 100;
    };
    const average = days.length
      ? days.reduce((sum, [, day]) => sum + read(day.entries), 0) / days.length
      : null;
    const foodDays = days.map(([, day]) => ({
      ...day,
      entries: day.entries.filter(
        (e) => catalog.find((f) => f.id === e.foodId)?.kind !== "supplement",
      ),
    }));
    const foodOnly = days.length
      ? foodDays.reduce((sum, d) => sum + read(d.entries), 0) / days.length
      : null;
    const supplementDays = days.filter(([, day]) =>
      day.entries.some(
        (e) => catalog.find((f) => f.id === e.foodId)?.kind === "supplement",
      ),
    ).length;
    return {
      key,
      label: d.toLocaleDateString("en-US", { month: "short" }),
      year: d.getFullYear(),
      average,
      foodOnly,
      loggedDays: days.length,
      supplementDays,
    };
  });
}
export function monthlyNutrients(state, catalog, endDate, months = 6) {
  return nutrients
    .filter((n) => n.group !== "Macros")
    .map((n) => ({
      ...n,
      months: trendBuckets(state, catalog, endDate, months, n.id),
    }));
}
export function nutrientPatterns(state, catalog, endDate, months = 6) {
  const end = new Date(endDate + "T12:00:00");
  const start = localDate(
    new Date(end.getFullYear(), end.getMonth() - months + 1, 1, 12),
  );
  const days = Object.entries(state.days)
    .filter(([date]) => date >= start && date <= endDate)
    .map(([, day]) => day.entries.filter((e) => !e.id.startsWith("sample-")))
    .filter((entries) => entries.length);
  const records = nutrients
    .filter((n) => n.group !== "Macros")
    .map((n) => {
      const known = days.filter((entries) =>
        entries.some(
          (e) => catalog.find((f) => f.id === e.foodId)?.values[n.id] != null,
        ),
      );
      const ratios = known.map(
        (entries) =>
          (totals(entries, catalog)[n.id] / state.targets[n.id]) * 100,
      );
      return {
        ...n,
        knownDays: known.length,
        average: ratios.length
          ? ratios.reduce((a, b) => a + b, 0) / ratios.length
          : null,
        below: ratios.filter((v) => v < 100).length,
        met: ratios.filter((v) => v >= 100).length,
        above: ratios.filter((v) => v > 100).length,
      };
    })
    .filter((n) => n.knownDays);
  return {
    below: [...records]
      .filter((n) => n.below)
      .sort(
        (a, b) =>
          b.below / b.knownDays - a.below / a.knownDays ||
          a.average - b.average,
      )
      .slice(0, 3),
    met: [...records]
      .filter((n) => n.met)
      .sort((a, b) => b.met / b.knownDays - a.met / a.knownDays)
      .slice(0, 3),
    above: [...records]
      .filter((n) => n.above)
      .sort(
        (a, b) =>
          b.above / b.knownDays - a.above / a.knownDays ||
          b.average - a.average,
      )
      .slice(0, 3),
  };
}
