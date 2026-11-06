# Nutrient design contract

Approved direction: 6 November 2026, following the Unslop / UI Best Practices review. The user approved the workflow proposal and asked that these rules persist as features grow.

## Product and character

A nutrition journal for someone logging meals and training toward a weight goal. Exact, calm, practical. Its world is a training journal and food scale: portions, food records, targets, shortfalls and contributions. The paired coverage/calorie rings and food-by-food nutrient detail carry the identity. Let real data provide the visual interest.

## Screen composition

- One clear task per screen. Today prioritizes progress, shortfalls, and correcting/logging food. Order: progress, remaining nutrients, food log, water, full nutrient catalog.
- Today has two aligned rings and three macro bars. Align the circle centers independently of caption wrapping. Accessibility text uses stacked linear progress instead.
- Expose Trends and Library by name. Measure their intrinsic label widths and adapt the header to available space; keep each navigation label intact. Fall back to navigation below the title, then vertically stacked controls, rather than relying on a text-size threshold. Keep Scan / Log food / Speak in a safe-area action dock, reachable while scrolling. This is an action group, not a bottom tab navigator.
- Show two shortfalls on Today and link to the full list. Food entries are directly editable; the diary editor remains discoverable.
- Trends groups frequency/range/nutrient controls ahead of the plot. Default to an explicitly labeled period average over recorded days; inspection changes to a dated value. Preserve daily, weekly and monthly aggregation and exact-value access.
- A chat proposal is the review surface: inspect and edit components there, select meal/date, then explicitly Confirm & log. Preserve grouping and reusable-meal options through disclosure. Each added feature should reduce the distance from intent to a correctable result.
- A saved recipe shows its portion, compact macro summary, and ingredient grams/calories. Edit mode exposes quantity/unit controls immediately, plus Add, Remove, Save and Cancel. Editing a recipe changes future logs; historical diary snapshots retain their original values.

## Visual system

Typography: Instrument Sans, selected after comparison with Manrope and Public Sans; Inter is the old baseline. Bundle local font files and licenses. Use `NutrientType.font` for semantic Dynamic Type scaling: body/headline 17 pt, secondary 15 pt, title2 22 pt, title 28 pt, largeTitle 34 pt at default size. Weight and spacing establish hierarchy; values use tabular digits. Keep primary content readable, with wrapping and stacking instead of shrinking essential text. Native system control/chrome typography may remain system-provided.

Colors: use the Field color assets. Background/surface/ink/secondary/rule establish hierarchy; fern is an action/coverage accent, ochre distinguishes calories and supplements, error identifies failures. Quantities remaining use ink, not success green. Retain the light/dark asset variants and check both. Communicate status in words as well as color.

Spacing: 4 pt base. `FieldSpace`: tight 4, item 8, controls 12, inset 16, section 24. Related content is closer than separate tasks. Minimum control target 44 pt, with comfortable 52–54 pt ingredient/capture rows. Dynamic Type may grow these minimums.

Depth: surface tones and subtle rules. Reserve the main card for the progress summary; other home sections use spacing and headings. Rounded controls 12 pt, summary card 20 pt, recipe/chat surfaces 16–20 pt. Keep chrome quiet; use solid fills and purposeful SF Symbols.

## Nutrition semantics

Coverage is a score out of 100: mean of 31 capped nutrient percentages. It is not the fraction of targets met. Display the score and target-completion count separately; explain the scope in coverage details. Macros and calories are separate from the 31 targets.

Unknown/unreported nutrient values remain distinct from zero, genuine shortfall and target met. Partial totals retain their partial marker. Empty/missing days are not zero intake. Period averages disclose their recorded-day denominator; never silently average missing dates into zeros.

## Interaction and motion

Numbers update immediately. Meters use an interruptible approximately 160 ms ease-out, with no artificial delay. Button feedback is short and restrained. Honor Reduce Motion. Keep chart selection local to the plot and guard updates within the same period; avoid redoing parent aggregation for every drag sample.

AI messages remain editable proposals; only explicit confirmation creates diary entries. Loading/error/retry are concrete. Camera and speech use native capture and actual permission/error states. Product copy names actions and data; leave promotional slogans and implementation footnotes out of screens.

## Completion checks for UI work

Build the native target and exercise affected flows with isolated fixtures. Review empty and populated content, light/dark mode, a narrow iPhone and accessibility text. Check safe areas, keyboard, reachable controls, no clipping, useful heading traits, and meaningful VoiceOver labels. Apply heading traits to titles only, rather than adjacent dates/counts. Verify Save/Cancel, quantity conversion, unknown data, and historical recipe preservation when touched. Report any checks not performed; screenshots are evidence, not a claim of full accessibility certification.

## Provenance

Adapted review method: Unslop by Damir Sokolovsky (@heydamir), https://heydamir.design/unslop, CC BY 4.0. Also informed by UI Best Practices and interface-design. The native composition and rules above are the approved Nutrient direction; external example styling does not override them.
