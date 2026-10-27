# Nutrient

An independent, free nutrition tracker inspired by the depth of Cronometer, with a calmer interface and nutrient coverage at the center. No subscriptions, locked charts, or paid nutrient breakdowns.

## Run locally

Requires Node.js 20.19+ or 22.12+.

```sh
npm install
npm run dev
```

Open the local URL printed by Vite. To verify and build:

```sh
npm test
npm run build
npm run preview
```

## What works

- Responsive overview with a nutrient coverage score, energy, macros, category scores, lowest-coverage nutrients, meal summaries, and water tracking.
- Date-based food diary, four meal groups, fractional servings, editing, moving, and removing entries.
- Searchable local food library and custom foods with all tracked nutrient fields.
- Free packaged-food barcode lookup through [Open Food Facts](https://world.openfoodfacts.org), with imported food values cached locally. No API key is needed. Enter the barcode digits; camera scanning is not implemented.
- Twenty-one nutrient breakdowns: 10 vitamins, 6 minerals, fiber, omega-3, and 3 macros. Click any nutrient for its contributing foods.
- Seven-day nutrient score chart based on actual diary entries, with empty days excluded from the average.
- Editable daily energy, macro, nutrient, and water targets.
- Browser-local persistence, validated JSON backup import, and full data export.

## Score definition

The daily score is the rounded, equally weighted mean of coverage for 18 nutrients (the 21 tracked nutrients excluding the 3 macros):

```text
coverage[nutrient] = min(100, intake / target × 100)
daily score = round(sum(coverage) / 18)
```

A nutrient above its target cannot compensate for another below target. Energy and macros are separate. This is a **coverage metric**, not an assessment of health, safety, absorption, excess intake, or upper tolerable limits. Historical scores recalculate using current targets.

## Food data and limits

The initial day is explicitly labeled **Sample day**. Sixteen built-in foods contain illustrative composition values, not a verified nutrition database. Use **Start fresh** to remove the sample day, create foods using label/verified values, or look up packaged foods by barcode.

Open Food Facts values are community supplied and may be incomplete or inaccurate; check against the package. Imported entries use a 100 g serving, so 0.3 servings means 30 g. API `*_100g` values in grams are converted to each nutrient's display units; calories use kcal or converted kJ. Missing nutrients remain `null` (unknown) and contribute zero to computed totals. Unknown values are identified in the contributing-food breakdown. No estimated micronutrients are substituted. Product carbohydrate data may follow regional labeling rules; the API's total-carbohydrate field is preferred when present.

Default targets are illustrative, editable starting points, not personalized recommendations. The tracker does not currently implement all essential nutrients, clinical scoring, recipes, exercise integration, weight tracking, account synchronization, camera scanning, or a comprehensive generic-food database. It is a functional first version rather than full Cronometer feature parity.

## Privacy and backups

Diaries, water logs, targets, and saved foods are stored in `localStorage` on the current origin. There is no account backend or cross-device sync. Clearing browser/site data deletes local records. Use JSON export to back up or transfer records. Import validates data and asks before replacing the existing diary. Switching between localhost and the hosted app creates separate storage.

The only external food request is an explicit barcode lookup to Open Food Facts. It sends the product code, not the diary or targets. The UI also loads DM Sans and Manrope from Google Fonts, with local fallbacks. There is no analytics or tracking integration.

## Project structure

- `app/main.js`: application views, accessible native dialogs, event handling, persistence.
- `app/style.css`: responsive design and semantic color/spacing system.
- `app/data.js`: sample foods, tracked nutrients, example targets, initial sample day.
- `app/model.js`: pure total, coverage, score, and backup validation functions.
- `app/open-food-facts.js`: barcode API and nutrition-unit conversion.
- `tests/`: Node test runner coverage for scoring, servings, import validation, and API adaptation.

## Data attribution

Barcode product information comes from [Open Food Facts](https://world.openfoodfacts.org), an open database under the [Open Database License (ODbL)](https://opendatacommons.org/licenses/odbl/1-0/). Data is retrieved using the [supported v2 product API](https://openfoodfacts.github.io/openfoodfacts-server/api/), without product images. Product data remains subject to its source license; this repository's sample data does not reproduce the Open Food Facts database. Preserve attribution in redistributed data or derived databases and review applicable source terms before distribution.

This project is independent and is not affiliated with Cronometer.
