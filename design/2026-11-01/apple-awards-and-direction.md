# Award references and the next visual pass

Researched November 1, 2026. The resulting native visual pass is now implemented; see the [implementation and verification record](identity/implementation.md). The research and recommendations below record the direction that informed it. This is a selected set of relevant references, not an objective ranking of mobile design awards.

## Primary Apple references

- **Tide Guide — 2026 Apple Design Award, Visuals and Graphics winner.** Apple highlights its chart presentation, aquatic theme, animation and contextual palette. The developer's site shows the current phone presentation and explains chart inspection. [Apple award record](https://developer.apple.com/design/awards/#visuals-and-graphics), [developer site](https://tideguide.com/).
- **Moonlitt — 2026 Apple Design Award, Interaction winner.** Apple's account identifies the SwiftUI implementation, onboarding and platform integration. Its connection to photography makes it relevant to the user's interests. [Apple award record](https://developer.apple.com/design/awards/#interaction).
- **Mela — 2025 Apple Design Award, Interaction finalist, not winner.** Apple describes context-sensitive cooking controls, native scanning and ingredient interactions. The developer's presentation emphasizes a readable recipe/ingredient hierarchy. [Apple finalist record](https://developer.apple.com/design/awards/2025/#interaction), [developer site](https://mela.recipes/).
- **(Not Boring) Camera — 2026 Apple Design Award, Visuals and Graphics finalist, not winner.** Apple describes tactile camera controls and an emphatic visual identity. Useful for distinctiveness, with restraint when applying it to repetitive nutrition logging. [Apple finalist record](https://developer.apple.com/design/awards/#visuals-and-graphics).

See [additional award references](award-references.md) for verified Indigo, iF and Red Dot examples.

## Visual evidence inspected

Viewed the Oura phone presentation linked from its Indigo entry, Mela's developer recipe screenshot (iPad), and Tide Guide's developer iPhone chart screenshot. Mela's image establishes typography and content hierarchy, not a verified iPhone layout. No app was installed or interaction-tested as part of this reference review.

- [Oura presentation image, credited to Instrument/Oura via Indigo](https://d3crlhnriidvt.cloudfront.net/lvegzw4gftnglsvcgm79ntinqrzg)
- [Mela recipe image, credited to Silvio Rizzi](https://mela.recipes/images/recipe.png)
- [Tide Guide phone chart image, credited to Condor Digital](https://tideguide.com/_image?f=webp&h=2589&href=%2F_astro%2Ftide-charts.BAJQHopk.png&q=86&w=2220)

## Our interpretation for Nutrient

The current native screen repeats similarly weighted rounded surfaces and green tints. This makes unrelated content feel structurally equivalent. Motion polish alone does not fix that.

1. Keep the user's two rings and three macro bars, but treat them as an open progress composition with clearer numeric hierarchy. Reduce the enclosing surface's visual weight.
2. Preserve prominent Scan and Quick log actions and tab-free navigation. Borrow clarity from award references without importing their navigation structures.
3. Give food records and ingredient quantities a disciplined, readable ledger treatment. Distinguish a food entry from an expandable form and from a primary action.
4. Use charcoal/ink and warm neutral space to carry structure; reserve a deliberate accent for actions and progress. Recheck light/dark contrast instead of washing the entire dark interface in green.
5. Let charts occupy a focused detail view with a fixed inspection readout. Preserve true data gaps and instant touch response. Tide Guide's continuous tide curve is not permission to smooth or invent nutrition observations.
6. Express the photography influence through composition, tonal contrast, and carefully selected color. Large decorative photos are optional and must not push logging or shortfalls offscreen.
7. Develop a distinctive app icon/wordmark and a consistent set of type, radius and surface rules. A new tint alone is insufficient.

Recommended synthesis: Oura's hierarchy, Mela's food-detail restraint, and Tide Guide's chart focus, adapted to Nutrient's existing product requirements. These are our design judgments; no award organizer has evaluated Nutrient.
