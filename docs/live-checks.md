# Live acceptance checks — 2026-10-27

Source under test: `06166f181cf8f3102f1e128bcacc61500ecce25c`. Provider: OpenRouter, `deepseek/deepseek-v4.1-flash`. The local ignored server environment supplied the credential; no key is included here.

## Verified live

- Exact food: 150 g roasted skinless chicken breast returned USDA 171477, source serving 100 g, quantity 1.5. Database trace had one exact match. Nutrition came from the stored source record; omega-3 remained unknown.
- Ambiguous food: “I had a burrito” searched database records then asked for origin, fillings and size. No proposal was returned.
- Missing branded food: one standard serving of CAVA Crazy Feta dip searched two database queries (zero matches) before requesting web fallback. The model returned a cited official CAVA PDF, 70 kcal, 4 g protein, 1 g carbohydrate, 6 g fat and 0 g fiber. Unreported micronutrients remained null. The extracted row was independently checked against the cited PDF. This verifies this extraction case, not comprehensive current restaurant coverage or future accuracy.
- Browser confirmation: the chicken proposal rendered 1.5 × 100 g and 248 rounded kcal. Before confirmation, the sample diary remained 1,203 kcal and score 79. Confirming added exactly one chicken entry to Breakfast (582 kcal total). Removing the synthetic test entry restored Breakfast to 334 kcal, total 1,203 kcal and score 79.
- All 25 automated tests passed.
- Production web build and Capacitor iOS sync passed. Xcode simulator build passed with signing disabled.
- Larger typography was checked at 390 px and 1440 px widths. Body and form text are 16–17 px, supporting text at least 14 px, with rem sizing and mobile layout reflow. Diary, nutrients, chat and trends had no page-wide horizontal overflow at 390 px. Dense charts scroll within their own containers.

## Remaining verification and configuration

- Test actual barcode recognition, permission denial/retry, and dictation start/stop on a physical iPhone. Simulator compilation does not verify camera/microphone hardware.
- The local server key does not provision hosted Sites runtime secrets. Configure OPENROUTER_API_KEY as a server secret on the hosted backend before using native chat against that URL. Never bundle a provider key in the native app or browser assets.
- Web extraction is a reviewable model output. The harness checks citation membership and numeric structure, not semantic correctness of every source or portion.

Evidence images are local ignored artifacts: `artifacts/live-meal-review.png` and `artifacts/readable-mobile.png`. They use synthetic foods and the labeled sample day.
