// Provisional personal plan requested 2026-10-27; preserve later edits.
export const personalCalorieTarget = 3500;
export const personalTargets = {
  protein: 160,
  carbs: 500,
  fat: 95,
  b6: 1.8,
  b12: 4,
  vitD: 25,
};
export function personalSupplements(nutrients) {
  const values = (reported) => ({
    ...Object.fromEntries(nutrients.map((n) => [n.id, null])),
    ...reported,
  });
  return [
    {
      id: "personal-d3-k2",
      name: "D3 1,000 IU + K2 45 µg",
      serving: "1 daily dose",
      kind: "supplement",
      calories: 0,
      energyUnreported: true,
      values: values({ vitD: 25, vitK: 45 }),
      source: "User-reported supplement dose",
      evidence:
        "User reports 1,000 IU vitamin D3 and 45 µg K2. Energy and other nutrients not supplied.",
    },
    {
      id: "personal-nordic-ultimate-omega",
      name: "Nordic Naturals Ultimate Omega",
      serving: "1 soft gel · 325 mg EPA + 225 mg DHA",
      kind: "supplement",
      calories: 10,
      values: values({ fat: 1, omega3: 0.64 }),
      source: "Nordic Naturals label · half of 2-soft-gel serving",
      sourceUrl:
        "https://www.nordicpro.com/products/nordic-naturals/ultimate-omega/",
      evidence:
        "Per two soft gels: 20 kcal, 2 g fat, 1,280 mg total omega-3, 650 mg EPA, 450 mg DHA.",
    },
  ];
}
export function migratePersonalTargets(state, supplements = []) {
  if (state.personalTargetVersion === 2) return false;
  Object.assign(state.targets, { protein: 160, carbs: 500, fat: 95 });
  const old = {
    protein: 100,
    carbs: 275,
    fat: 78,
    b6: 1.3,
    b12: 2.4,
    vitD: 15,
  };
  if (state.calorieTarget === 2200) state.calorieTarget = personalCalorieTarget;
  for (const [id, value] of Object.entries(personalTargets))
    if (state.targets[id] === old[id]) state.targets[id] = value;
  for (const food of supplements)
    if (!state.customFoods.some((f) => f.id === food.id))
      state.customFoods.push(structuredClone(food));
  state.personalTargetVersion = 2;
  return true;
}
