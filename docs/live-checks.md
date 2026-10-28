# Live acceptance checks — 2026-10-27

Source under test: `06166f181cf8f3102f1e128bcacc61500ecce25c`. Provider: OpenRouter, `deepseek/deepseek-v4.1-flash`. The local ignored server environment supplied the credential; no key is included here.

## Verified live

- Exact food: 150 g roasted skinless chicken breast returned USDA 171477, source serving 100 g, quantity 1.5. Database trace had one exact match. Nutrition came from the stored source record; omega-3 remained unknown.
- Ambiguous food: “I had a burrito” searched database records then asked for origin, fillings and size. No proposal was returned.
- Missing branded food: one standard serving of CAVA Crazy Feta dip searched two database queries (zero matches) before requesting web fallback. The model returned a cited official CAVA PDF, 70 kcal, 4 g protein, 1 g carbohydrate, 6 g fat and 0 g fiber. Unreported micronutrients remained null. The extracted row was independently checked against the cited PDF. This verifies this extraction case, not comprehensive current restaurant coverage or future accuracy.
- Browser confirmation: the chicken proposal rendered 1.5 × 100 g and 248 rounded kcal. Before confirmation, the sample diary remained 1,203 kcal and score 79. Confirming added exactly one chicken entry to Breakfast (582 kcal total). Removing the synthetic test entry restored Breakfast to 334 kcal, total 1,203 kcal and score 79.
- All 25 automated tests passed.
- Production web build and Capacitor iOS sync passed. Xcode simulator build passed with signing disabled. The actual `iphoneos` arm64 build also passed with signing disabled, compiling and linking the native scanner and speech implementation for device hardware. This unsigned artifact cannot be installed on an iPhone; signing remains required.
- Larger typography was checked at 390 px and 1440 px widths. Body and form text are 16–17 px, supporting text at least 14 px, with rem sizing and mobile layout reflow. Diary, nutrients, chat and trends had no page-wide horizontal overflow at 390 px. Dense charts scroll within their own containers.

## Remaining verification and configuration

- Test actual barcode recognition, permission denial/retry, and dictation start/stop on a physical iPhone. Simulator compilation does not verify camera/microphone hardware. A paired iPhone was detected, but the device build failed because Xcode reported “No Accounts” and no development provisioning profile for `com.kggreco11.nutrient`. Sign in through Xcode Settings → Accounts, then retry the development build using the existing Apple team. No device app was installed by this attempt.
- Hosted backend configured with `OPENROUTER_API_KEY` as a masked runtime secret (environment revision 1), and the saved production version redeployed successfully. An authenticated `capacitor://localhost` request returned HTTP 200 for status and chat; an ambiguous burrito returned questions with no proposal. Private native clients still need the Site service-access token in backend settings. Never bundle either credential in source or browser assets.
- Web extraction is a reviewable model output. The harness checks citation membership and numeric structure, not semantic correctness of every source or portion.

Evidence images are local ignored artifacts: `artifacts/live-meal-review.png` and `artifacts/readable-mobile.png`. They use synthetic foods and the labeled sample day.

## SwiftUI replacement — 2026-10-27

The iPhone target now launches a SwiftUI hosting controller directly and no longer links Capacitor or copies website resources. Both simulator and signed arm64 device builds succeeded. The signed app was installed on the paired iPhone. Inspection of the built app found no HTML files.

A native URLSession request to the private hosted assistant returned HTTP 200 with a reply. A second launch, without supplying a credential, also returned HTTP 200, verifying Keychain persistence. Temporary verification code was removed from the final build. The OpenRouter key remains server-side.

In the simulator, the native chat sent a synthetic 150 g chicken description and received preparation questions from the live assistant. Native Today and Chat retain the same system tab bar position with the keyboard dismissed. Screens use native lists/forms and hide scroll indicators. Trends now shows average daily amounts against targets and gaps rather than ranking nutrients from one recorded day.

The prior Capacitor, unsigned-build and account-signing limitations above describe the earlier implementation and are superseded by this SwiftUI build. Physical barcode recognition and spoken dictation remain hardware checks; successful compilation does not prove recognition quality.

Final native acceptance: the simulator follow-up selected roasted, skinless meat. The native review sheet showed USDA SR Legacy, 1.5 × 100 g, and 248 rounded kcal. Confirmation added the entry and updated native Trends. The software keyboard displayed beneath the composer, while the system tab bar stayed out of the composition area. Final clean builds passed for both simulator and signed device. Bundle inspection found zero HTML, JavaScript or CSS assets and zero Capacitor frameworks. All 29 server/web regression tests and the web production build passed.
