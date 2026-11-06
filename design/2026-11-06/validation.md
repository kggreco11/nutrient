# Native implementation validation

6 November 2026

- Debug iPhone Simulator build succeeded with code signing disabled. Simulator: iPhone 17, iOS 26.3. Final build includes Instrument Sans font registration and all four static font faces.
- `npm run test:native` passed: label OCR, conversion and food-specific measures, partial/unknown nutrient data, logging and persistence, diary editing, recipe snapshots and rollback, daily/weekly/monthly aggregation, chart selection guard, and light/dark accent contrast.
- Direct native UI check: Today → Trends works and navigation back remains visible. Coverage score is displayed out of 100 independently of target-completion count. Headings no longer include adjacent metadata as separate headings.
- Direct native chat check with isolated fixtures: expanded bread, changed 64 g to 96 g; draft recalculated 347 → 432 kcal and 17 → 21 g protein. Confirm & log removed the draft and appended the logged message. No second review sheet or live API call.
- Native editor was inspected with ingredient amount/unit controls immediately exposed. Final compact variant shares the same conversion binding; accessibility text stacks the controls.
- Reviewed final Today screenshots in light and dark modes and the stacked home layout at accessibility-large text size. Restored original simulator settings (large text category, dark appearance) afterward.
- Font comparison reviewed Manrope, Public Sans and Instrument Sans on the same local Today composition. The local prototype retains all three plus the old Inter baseline in its type selector.
- `git diff --check`, Info.plist lint and prototype JavaScript syntax checks pass.
- Captures use isolated synthetic fixture data. Restored Simulator to normal app launch after verification.

No publication, Git push or physical-phone installation. No new backend/model behavior was changed or tested. A full VoiceOver pass, smallest-device matrix, camera/speech permissions on a real phone and real-device touch performance remain unverified. Existing build warnings include a pre-existing ambiguous trailing closure and skipped AppIntents metadata extraction.

## Home navigation wrapping regression

Reproduced Trends/Library splitting across lines on iPhone 17 at the largest standard text size. The header only switched orientation for accessibility categories, allowing compression below each label’s intrinsic width. Replaced that threshold with available-width layout selection and uncompressed navigation labels; the fallback places navigation below the date and stacks its controls when needed. Verified native iPhone 16e (390 pt) at default, largest standard and maximum accessibility text sizes, with empty/populated fixtures. Simulator and signed device builds pass. No model or persistence behavior changed.
