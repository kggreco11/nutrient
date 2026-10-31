# Design audit: spacing, hierarchy, and AI defaults

Reviewed 31 October 2026 against commit dfa52eb.

Implementation status: the eight findings have been addressed in the [polish implementation record](fixes.md). The findings below describe the original baseline.

## Verdict

Keep the Journal direction, the photography-derived palette, two rings and three bars, direct capture actions, and the tab-free navigation. The next pass should address density and progressive disclosure. Another palette or navigation rewrite would not resolve the main problems.

The largest defect is drift between the compact mockup and the native implementation. Source inspection and the current native home screenshot establish this; a browser overflow check cannot establish that the native layout has the right density.

## Findings, in priority order

### 1. P1 — Progress pushes the shortfalls out of the initial native viewport

Evidence: NativeApp.swift lines 84–169. The native rings start at 116 pt, each has 12 pt gaps between its labels and graphic, and their row has 12 pt vertical padding. Macro rows add their own spacing and padding inside an inset-grouped list. The current empty-day Simulator rendering only reaches the nutrient-gap section near the bottom of the viewport. Populated gap rows would begin there too.

The Journal mockup instead specifies 90 px rings and tighter internal layout in navigation.css lines 20–37. It also uses 14 px macro labels, so copying that mockup literally would reduce text size unnecessarily.

Recommendation: keep readable type and reduce wrapper geometry. Use roughly 100 pt rings at standard type, 8 pt ring-label gaps, a single shared progress surface, and macro rows with a 52–56 pt minimum touch area. Give the home explicit section spacing rather than stacking implicit List spacing and multiple padding layers.

Acceptance: on a 393 × 852 pt phone at default type, both capture actions, two rings, three macro bars, and at least two populated shortfalls should be visible without scrolling. At accessibility sizes, let content grow and scroll; this fold target must not become a clipping rule.

### 2. P2 — Spacing is chosen locally, with no shared density contract

Evidence: FieldSurface sets a global 52 pt minimum row height, while DashboardRing, Today, nutrient rows, food rows, and meal drafts independently add 4, 5, 7, 8, 10, 12, 16, and 18 pt spacing or padding.

Those values are not individually wrong. The problem is that nested layers do not share a definition of “inside an item,” “inside a group,” and “between groups.” This creates a loose screen even when each component appears reasonable alone.

Recommendation: adopt the proposed role-based spacing table below, first for Today and meal review. Use native system margins where appropriate. Optical exceptions are allowed; mechanical enforcement of multiples of four is not the goal.

### 3. P2 — Meal review expands every ingredient into a form

Evidence: NativeMealReview at line 921 embeds NativeQuantityInput for every ingredient. Each input shows amount, unit, and a gram/serving equivalent. Source metadata and source links can add more rows. The final confirmation is already pinned correctly.

Recommendation: show a compact ingredient ledger with food name, current amount, and energy. Tapping a row expands its amount/unit editor; keep one expanded by default only when it needs attention. Keep Scan another item and Add from foods beside the ingredient list. Retain the fixed confirmation and all provenance details through disclosure.

Acceptance: a three-ingredient meal is readable as one meal before the user opens quantity editors. Editing one amount preserves the other quantities and the selected date.

### 4. P2 — Trends puts the exhaustive dated table before nutrient priorities

Evidence: NativeTrends renders the full “By day / week / month” section at line 1215 before “Average daily intake” at line 1233. The averages are already sorted by percentage in NativeModels.swift; the issue is their position, not their ordering.

Recommendation: chart, then the three most important recorded shortfalls, then expandable full dated values and all nutrient averages. Preserve exact dated access and unknown-data semantics. A selected-point value would improve the chart, but is a separate interaction change to verify.

### 5. P2 — Some large-text layouts rely on text compression

Evidence: DashboardRing uses a fixed scaled graphic with a single-line number and a 0.75 minimum scale factor. NativeNutrientDetail uses horizontal name/value rows with fixed-size contribution amounts. General nutrient rows also pair long names with amounts horizontally.

These are source-supported risks, not newly reproduced failures on every screen.

Recommendation: switch label/value groups to vertical arrangements when they do not fit, using Dynamic Type and fit-based layout. Keep figures together without shrinking normal reading text. Verify large values, long product names, and accessibility sizes on the actual native surface.

### 6. P2 — Quick log can move the scroll position while a person reads history

Evidence: NativeChat lines 787–793 unconditionally animates to the bottom when history count or sending state changes; no reduced-motion or near-bottom condition is present.

Recommendation: scroll to the composer for the user's send action. When an incoming response arrives, follow it only if the person is already near the bottom. Respect Reduce Motion. This needs interaction verification, not a screenshot-only check.

### 7. P3 — The home toolbar has an ambiguous duplicate entry action

Evidence: the large Quick log action and the toolbar plus both imply adding food; the plus actually opens database search. The distinction is not visible until tapped.

Recommendation: use a search symbol with the accessible label “Search foods,” leaving Scan barcode and Quick log as the two clear home actions. Native capsule buttons are appropriate on iOS; their shape is not itself an AI-design defect.

### 8. P2 — Calorie overage loses its status wording

Evidence: Today uses max(0, target − intake) for “kcal left” at line 146. Above the target it reports zero left rather than the amount over. The central consumed value remains accurate.

Recommendation: display “X kcal over” above target. Keep the ring capped if useful, but retain the actual value and status in text. No warning modal or supplement recommendation is needed.

## Proposed spacing and type contract

These are app-specific design decisions, not numeric requirements claimed to come from Apple.

| Role | Proposed value / behavior |
| --- | --- |
| Horizontal page gutter | 20 pt baseline; honor platform safe areas and readable widths |
| Surface inset | 16 pt |
| Closely related label/value gap | 4–8 pt |
| Sibling controls | 12 pt |
| Separate content groups | 24 pt; avoid adding both parent and child outer gaps |
| Capture buttons | 52–56 pt baseline; grow with content |
| Row targets | At least 44 × 44 pt hit region; generally 52–56 pt baseline for tappable data rows |
| Rings | About 100 pt at standard type; enlarged/stacked at accessibility sizes |
| Body and actionable food labels | Native body style, normally 17 pt |
| Secondary quantities | Native subheadline, normally 15 pt |
| Main figures | Native title/title2 styles; no fixed pixel text-size cap |
| Container hierarchy | One surface per meaningful group; fine separators inside |

First implementation slice: unify the native home progress group, tune capture/section spacing, clarify toolbar search, and verify two shortfalls are visible. Then compact meal review. The rest can follow without another structural redesign.

## What already works

- The palette and short serif titles have a specific connection to Kevin's photography and site.
- Scan and Quick log are direct home actions; chat is an action sheet rather than a navigation tab.
- The fixed meal confirmation, native controls, named light/dark text colors, source-food drilldown, and explicit unknown nutrition states are useful foundations.
- Existing color results record text contrast checks. They do not certify every system control, disabled state, chart, or accessibility interaction.

## Current sources and how they apply

- [Apple, Layout](https://developer.apple.com/design/human-interface-guidelines/layout): group related information, give essential content room, align content, and adapt to safe areas and text changes. This supports targeted density changes, not indiscriminate compression.
- [Apple, Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons): appropriate hit regions and consistent paired controls. Keep accessible capture actions while reducing unnecessary outer space.
- [Apple, Principles of great design, WWDC26](https://developer.apple.com/videos/play/wwdc2026/250/): order, spacing, and contrast communicate priority. Use this to judge whether daily shortfalls are actually easy to find.
- [Vercel, Teaching agents product design, 25 June 2026](https://vercel.com/blog/teaching-agents-product-design-at-vercel): preserve product reasoning, review the rendered surface, and resolve hierarchy before adding containers. Apply the workflow principles rather than importing Vercel's web component styling.
- [Impeccable, Slop catalog](https://impeccable.style/slop/): relevant checks include repeated structures with changed colors, excessive nested containers, and spacing that does not communicate relationships. This is a critique reference; no Impeccable runtime detector was run.

The direct X search connector returned an authentication error, with no reported charge. Public web search did not produce verifiable recent X posts for the targeted queries. This audit therefore does not claim to summarize a particular viral thread or establish current Twitter consensus. The primary sources above were read directly.

## Scope and evidence limits

The native home was visually inspected in Simulator and checked against current source. Secondary findings are based on the SwiftUI implementations and prior artifacts; not every interaction or data state was newly exercised. No native production code was changed during this audit.

The next verification pass should include a populated day, empty day, intake above target, long food names, keyboard and dictation, VoiceOver, Reduce Motion, largest text sizes, and at least one smaller iPhone. The earlier browser overflow checks are useful but cannot substitute for these native checks.
