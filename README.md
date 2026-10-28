# Nutrient

An independent nutrition tracker for iOS and the web. Today's nutrient progress is the home screen; a separate Trends tab shows monthly averages, target coverage and recurring gaps. There are no nutrient paywalls or background AI analysis jobs.

## Run

Node.js 20.19+ or 22.12+, npm, and Xcode for iOS.

```sh
npm install
npm run dev
```

The browser preview runs at the URL Vite prints. The dev server includes the server-only assistant endpoint.

```sh
npm test
npm run build
npm run ios:sync
npm run ios:open
```

The iPhone app is written in **SwiftUI**, with a native `TabView`, `NavigationStack`, forms, lists and Swift Charts. `SceneDelegate.swift` hosts `NutrientAppView` directly. It does not load a web view, HTML, CSS, JavaScript or Capacitor runtime. Minimum deployment target: iOS 17. Bundle ID: `com.kggreco11.nutrient`.

`npm run ios:sync` refreshes the bundled USDA dataset and reference targets from the shared data sources. Open `ios/App/App.xcodeproj` in Xcode to build and run. The native interface lives in `NativeApp.swift`; persistence/calculations in `NativeModels.swift`; networking and Keychain access in `NativeBackend.swift`; camera and dictation in `NativeCapture.swift`.

The web companion is a separate Vite application. `npm run build` produces `dist/client` for the website and `dist/server/index.js` for the hosted assistant backend. Those website assets are not included in the iPhone bundle. Legacy Capacitor files remain for migration reference and web utilities, but the Xcode app target has no Capacitor dependency or web resources.

## Conversational logging

Conversation understanding belongs to the **LLM**, not a handwritten food parser. The server defaults to OpenRouter's `deepseek/deepseek-v4.1-flash`, configurable through `OPENROUTER_MODEL`.

1. The user describes foods, restaurant components, supplements and portions in chat or dictates a transcript.
2. The model searches saved foods and USDA records through `search_food_database`. Packaged products can use `lookup_barcode`.
3. The assistant asks about unclear food identity, preparation, components or amounts.
4. After a database lookup proves insufficient, `request_web_fallback` enables OpenRouter web search and page/PDF fetching. The system prompt requires official manufacturer/restaurant sources, source citations and explicit serving bases. No restaurant has a special hardcoded flow.
5. `propose_meal` returns food records and serving multipliers. Database IDs must have appeared in tool results. Sourced nutrition must cite a returned URL and supply explicit values or nulls.
6. The app independently totals the proposal, displays its sources and missing data, and **waits for Confirm & log meal**. No model tool can write a diary entry.

The single source of assistant instructions is [`server/policy.js`](server/policy.js); orchestration and tool validation are in [`server/agent.js`](server/agent.js). The model cannot invoke arbitrary application actions. Retrieved content is treated as evidence, not instructions. Search is enabled after database lookup, with bounded model/tool rounds and output tokens. See [`docs/assistant.md`](docs/assistant.md) for the contract and limits.

### OpenRouter setup

Copy `.env.example` to ignored `.env.local` and set `OPENROUTER_API_KEY` locally. Do not paste the key into chat, app fields, source code, Vite client variables, or a GitHub commit. Restart the dev server after changing this file. `OPENROUTER_MODEL` defaults to `deepseek/deepseek-v4.1-flash`.

For the hosted Worker, configure these as server runtime values in the hosting service. Local `.env.local` values are not uploaded or automatically deployed. Model tokens and web tools consume OpenRouter credits. The app's nutrient views and manual food logging work without an AI key. Automated server tests mock provider responses; live checks are documented separately.

`GET /api/status` reports whether a provider key is configured, without returning it. `POST /api/chat` runs a user-triggered conversation turn. Private hosted access is enforced by Sites. Standalone/native API deployments can use a separate `NUTRIENT_API_TOKEN`; do not use the OpenRouter key as an app access token. The native app calls the private hosted assistant using URLSession and a service-access credential stored in iOS Keychain. Settings → Chat connection can reconnect the service. Development provisioning may supply `NUTRIENT_SERVICE_TOKEN` as a launch environment variable; it is saved to Keychain and removed from the app's process environment. It is not the OpenRouter key. Neither credential is bundled, committed or included in backups.

## Nutrition data

- **USDA FoodData Central, SR Legacy:** 7,793 bundled searchable food records, including 312 historical fast-food records. Downloaded from USDA's official public dataset. It is the final **April 2018 SR release**, published into FoodData Central in 2019, not a current restaurant-menu database. Source IDs and a checksum are recorded. Values are per 100 g. No API key is needed.
- **Open Food Facts:** native camera UPC/EAN scanning and browser camera scanning look up real packaged products through the supported product API. Manual barcode entry remains a fallback. Community data can be incomplete; verify against the label.
- **Saved foods and sourced labels:** users can add custom food or supplement labels with source URLs, then reuse them.
- **Official public nutrition sources:** a configured LLM can find and read manufacturer/restaurant pages when databases lack a suitable match. Its extracted values remain explicitly reviewable and are not treated as independently verified facts.

The app does not claim comprehensive current restaurant coverage. Aggregators such as FatSecret or Nutritionix can be added to the database tool behind the same interface when access is available. Do not scrape arbitrary sites as the default strategy or silently replace branded recipes with generic foods.

Reproduce the bundled database:

```sh
python3 scripts/import-usda.py
# Or use a previously downloaded official ZIP:
python3 scripts/import-usda.py /path/to/FoodData_Central_sr_legacy_food_csv_2018-04.zip
```

The importer uses Vitamin A as RAE, folate as DFE and vitamin D in micrograms. Combined omega-3 is reported only when all four explicit ALA/EPA/DHA/DPA values exist. Missing data remains `null`; zero means a reported zero. See `public/data/usda-manifest.json`.

## Saved meals and supplements

Library has foods, reusable composite meals and supplements. Build a meal from database or saved components, specify each serving multiplier, then save it under a name such as a usual breakfast. Saved meals snapshot component sources, portions and nutrient values. A partial nutrient total includes known contributions and is marked incomplete.

Supplement labels use the actual nutrient amounts per capsule/tablet/serving, not percent Daily Value. The diary has a separate Supplements section. Today shows food-only coverage alongside combined coverage; historical charts distinguish food from supplement contributions. Logging a supplement is not a dosage recommendation.

Editing a saved food creates a new version and archives the old one, preserving historical diary values. Archiving removes an item from the active library without destroying existing logs.

## Trends

Select 3, 6 or 12 months and an overall score, energy or individual nutrient. The chart shows monthly averages and the target line. Empty days and initial sample entries are excluded. Per-nutrient averages exclude days with no reported value for that nutrient. The nutrient grid shows monthly coverage, and an intake summary lists average daily amounts, targets and gaps, sorted by lowest target coverage. One recorded day is not described as a recurring pattern. These are deterministic calculations performed when you open Trends; no model calls, polling jobs, forecasts or ongoing analysis are involved.

Overall score is the mean of 18 capped nutrient-coverage percentages (10 vitamins, 6 minerals, fiber and omega-3), rounded to an integer. Macros and energy are separate. A nutrient above target cannot mask a gap in another. Individual nutrient trends retain percentages above 100 so over-target patterns stay visible. Targets are current, editable examples, not personalized clinical recommendations. Coverage does not assess absorption, health, nutrient interactions or safe upper limits.

## iOS camera, dictation and data

The native scanner uses AVFoundation's camera and barcode recognition. Web preview uses ZXing. Camera frames are processed on-device; decoded digits are sent to Open Food Facts. Native dictation uses Apple's Speech and AVFoundation APIs. A transcript is sent to the assistant only when Send is tapped. Hardware recognition still needs a physical camera/microphone acceptance check.

Native diary data persists as an atomic JSON file in Application Support. Existing Capacitor Preferences data is read on first migration; future saves also retain a compatible preferences copy. Unreadable data is saved separately for recovery. Web data uses localStorage. There is no account synchronization. Export/import JSON transfers diary entries, targets and the saved library; import validates records and asks before replacing data. The private chat credential stays in Keychain.

The initial **Sample day** and 16 illustrative foods are explicitly labeled. Start fresh removes sample entries. Historical patterns exclude sample entries even if you add real food on the sample date.

## Data attribution

USDA FoodData Central data is public domain/CC0. Source: [USDA downloads](https://fdc.nal.usda.gov/download-datasets/). Barcode data comes from [Open Food Facts](https://world.openfoodfacts.org), under [ODbL](https://opendatacommons.org/licenses/odbl/1-0/); preserve attribution and comply with applicable database terms when redistributing derived product data. Web nutrition records retain their original source URLs.

This project is independent and not affiliated with Cronometer or any restaurant or nutrition-data provider.

## Reference targets and recorded shortfalls

Tracked micronutrient defaults now use U.S./Canadian male age 19–30 RDA/AI values, with fiber at 38 g. Source links are shown in Settings. These intake references do not represent deficiency treatment, blood levels, or supplement doses. Macros/energy remain separately editable; the combined omega-3 field remains a user-editable tracking target, not a distinct ALA/EPA/DHA recommendation.

On first load, legacy default values migrate once; values differing from the old defaults are preserved. A previously customized value identical to an old default cannot be distinguished from an untouched default. Imported legacy backups use the same migration. Historical entries are unchanged; charts compare them against current targets.

Intake summaries describe recorded intake and report complete versus reported days, plus entirely unknown days. Days without any reported value for a nutrient are excluded from that nutrient's averages. Partial records can understate intake. The app does not diagnose deficiencies or recommend supplements.
