// U.S./Canadian DRI reference intakes for men age 19–30, not treatment doses.
// https://www.canada.ca/en/health-canada/services/food-nutrition/healthy-eating/dietary-reference-intakes/tables/reference-values-vitamins.html
// https://www.canada.ca/en/health-canada/services/food-nutrition/healthy-eating/dietary-reference-intakes/tables/reference-values-elements.html
export const referenceTargets = {
  fiber: 38,
  vitA: 900,
  vitC: 90,
  vitD: 15,
  vitE: 15,
  vitK: 120,
  b1: 1.2,
  b2: 1.3,
  b6: 1.3,
  b12: 2.4,
  folate: 400,
  calcium: 1000,
  iron: 8,
  magnesium: 400,
  potassium: 3400,
  zinc: 11,
  selenium: 55,
};
const legacyTargets = {
  ...referenceTargets,
  fiber: 28,
  vitD: 20,
  b6: 1.7,
  calcium: 1300,
  iron: 18,
  magnesium: 420,
  potassium: 4700,
};
export function migrateReferenceTargets(state) {
  if (state.referenceTargetVersion === 1) return false;
  for (const [id, value] of Object.entries(referenceTargets)) {
    if (state.targets[id] === legacyTargets[id]) state.targets[id] = value;
  }
  state.referenceTargetVersion = 1;
  return true;
}
