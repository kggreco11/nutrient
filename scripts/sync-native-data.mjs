import { writeFileSync, copyFileSync } from "node:fs";
import { nutrients, foods, defaultTargets } from "../app/data.js";
writeFileSync(
  new URL("../ios/App/App/NativeSeed.json", import.meta.url),
  JSON.stringify({ nutrients, foods, targets: defaultTargets }),
);
copyFileSync(
  new URL("../public/data/usda-sr-legacy.json", import.meta.url),
  new URL("../ios/App/App/FoodDatabase.json", import.meta.url),
);
console.log(
  "Synced native food data. iOS uses SwiftUI; no web build is copied into the app.",
);
