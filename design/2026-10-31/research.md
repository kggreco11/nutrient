# Nutrient: three iPhone design directions

Design review created 31 October 2026. These are interactive visual proposals for the native SwiftUI product; they do not replace the running iOS app with a website.

## GitHub skill research

GitHub has no universal individual-skill rating. Repository stars are a reproducible popularity proxy. Counts were read from the GitHub repository API on 2026-10-31, alongside broader repository searches. This is a researched shortlist, not a claim to have exhaustively ranked all GitHub repositories.

| Skill | Repository stars | Application |
| --- | ---: | --- |
| [Anthropic Frontend Design](https://github.com/anthropics/skills/tree/main/skills/frontend-design) | 185,794, repository-wide | Read and applied: product-specific visual worlds, deliberate typography, minimal copy, two-pass design critique. iOS system text styles take precedence over web font suggestions. |
| [UI/UX Pro Max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | 143,336 | Read and applied: SwiftUI search results, touch-target guidance, chart accessibility, mobile delivery checklist. Ran the local search tool after inspecting its Python modules. |
| [Impeccable](https://github.com/pbakaus/impeccable) | 98,032 | Reviewed as a comparator: task-oriented interface restraint and native expectations. Its auto-downloading binary launcher was not installed or run; this proposal does not claim a completed Impeccable runtime workflow. |
| [Interface Design](https://github.com/Dammyjay93/interface-design) | 5,885 | Existing installed skill provides the product-domain exploration and interface consistency discipline. |

The Pro Max product-wide generator returned a marketing-page structure with testimonials on both the initial query and one narrower retry. That structure was rejected as unsuitable for a native food diary. Its verified SwiftUI, touch-size, and time-series results were retained; the visual systems below are authored for Nutrient, not attributed to a nonexistent database match.

## Primary mobile references

- [Apple: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility): adaptable layouts, text enlargement, multimodal communication, contrast, and appropriately sized controls.
- [Apple: Typography](https://developer.apple.com/design/human-interface-guidelines/typography): 17 pt default iOS body size, built-in text styles, Dynamic Type, system fonts, and minimal truncation.
- [Apple: Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars): stable, labeled top-level navigation; tabs navigate rather than perform actions; modal tasks can temporarily cover navigation.

Apple's live Markdown versions were read when the documentation site's JavaScript shell prevented normal extraction. The prototype uses system typography and consistent outline symbols as visual stand-ins; native implementation should use SF Symbols.

## Shared mobile contract

- Native SwiftUI `TabView` and navigation stacks remain the implementation target.
- Five stable, labeled tabs: Today, Diary, Chat, Trends, Library. Settings moves to a secondary toolbar destination instead of occupying a More tab.
- 17 pt body baseline; primary figures 28–42 pt; supporting information normally 14–15 pt. No low-contrast dark green text.
- 44 pt minimum controls; important actions 48 pt high. At least 8 pt separation between adjacent icon controls.
- Status/sensor area, home indicator, bottom navigation, composer, and confirmation actions each reserve space. Content scrolls inside the safe region.
- Chat contains messages, an editable meal proposal, and a composer. No welcome slogans, workspace cards, or repeated disclaimers.
- Today's two rings and three macro bars remain. Largest known gaps surface immediately with remaining amounts and an explicit route to food suggestions.
- Graphs include exact dated values. Daily / Weekly / Monthly are direct controls. Unknown intake is separate from explicit zero.
- Use native keyboard avoidance; keep composer above keyboard and predictable navigation. Native implementation must be tested on an actual iPhone with keyboard and dictation active.
- Light and dark colors are independent token pairs; color never carries status by itself. Reduced Motion is respected.
- The viewer's 375 pt, larger text, 200% text, and landscape controls are visual stress tests. They do not substitute for VoiceOver, real Dynamic Type, Switch Control, or device-level certification.

## Three directions

### Field — a personal field journal (recommended)

- Product world: nutrient accounting, measured portions, dated observations, traceable foods, field notes.
- Colors: chalk `#F3F4EF`, fern `#365F4D`, ink `#25352F`, rules `#D4DDD1`, ochre `#805E30`. Dark mode: forest `#171F1B`, lifted surface `#222E27`, bright fern `#B1D8BA` and pale ochre `#E1C294`.
- Type: short system-serif titles echo Kevin’s site; system sans for operational text, tabular numbers for amounts.
- Structure: two-ring summary, macro bars, ranked shortfalls, readable diary rows, direct Library tab.
- Signature: every progress number leads to source foods or a concrete amount left; thin scientific rules and landscape colors connect to Kevin’s work.
- Tradeoff: quiet character, prioritizing repeated daily use.

### Slate — light against structure

- Product world: daily fuel, measured ingredients, weekly consistency, architectural framing.
- Colors: graphite `#191F23`, silver-blue `#B9D5E2`, structural gray `#45535C`, warm light `#E4C697`.
- Type: system sans with stronger numeric weight; linear separators and less floating-card decoration.
- Structure: open progress instrument, ingredient ledger, bar-based trends, compact source comparisons. Light counterpart included.
- Signature: coordinated progress instruments, clear vertical alignment inspired by Kevin’s monochrome upward-looking city photographs.
- Tradeoff: more data-forward, less relaxed.

### Golden — the last light

- Product world: familiar breakfast, assembled ingredients, saved recipes, daily food journal.
- Colors: pale stone `#F4F1EA`, umber `#805A2A`, warm ink `#3B322A`, ochre and muted herb `#576D50`.
- Type: system sans for operational text; short serif titles and selected large figures.
- Structure: open summary, recipe-led diary groups, fuller meal-library rows, weekly score strip.
- Signature: familiar assembled meals, and small warm-light accents inspired by city sunlight and wildlife landscapes.
- Tradeoff: warmest identity, less dense than Slate.

## Interface coverage

Every direction includes these reviewable screens, not just a recolored home page:

| Existing interface / task | Proposed treatment |
| --- | --- |
| Today | Two rings, three bars, ranked gaps, recent meal |
| Daily coverage / all nutrients | Still to go / All / Met filter; unknown values separated |
| Nutrient detail | Total, remaining amount, source food contributions |
| Diary | Readable meal groups, dated entries, selection action |
| Edit diary entry | Amount + unit + gram equivalent, meal and date |
| Select diary entries | Checkmarks, selected count, fixed Save as meal action |
| Save diary selection | Name and captured ingredients; library save only |
| Add food / search | Search, barcode, label photo, and describe-food routes |
| Barcode scan | Capture surface plus the current meal draft |
| Label scan | Full-panel framing, take or choose photo |
| Custom food / scanned label | Name, serving, weight, editable extracted nutrition |
| Meal review | Per-ingredient amounts, scan next, add food, grouped logging |
| Measurement editor | Selected unit, converted gram weight, updated nutrition |
| Chat | Messages, proposal card, composer, retry state |
| Trends | Daily / Weekly / Monthly, target line, exact values |
| Library | Meals / Foods / Supplements with reusable recipe rows |
| Saved meal | Ingredient snapshot and one explicit logging action |
| Meal builder | Recipe name, ingredients, scan/add, serving count |
| Supplements | Actual per-dose catalog and label capture |
| Settings / targets | Clearly labeled editable targets and data/connection controls |
| Empty and error states | Direct next action; retained message on retry |

## Review artifacts

- `index.html`: interactive viewer; direction, screen, appearance, phone width, and text size controls.
- `clear-board.jpg`, `pace-board.jpg`, `table-board.jpg`: six-screen direction overviews.
- Boards show Today, Diary, Chat, Trends, Library, and meal review; the viewer contains secondary workflows and edge states.
- Mock values are illustrative. UI controls simulate navigation; they do not write to the production diary or call the nutrition model.

## Native implementation

Field is now implemented in SwiftUI as the recommended default. Slate and Golden remain alternative review directions. The native changes include named light/dark tokens, shared list/form surfaces, short serif navigation titles, adaptive rings, Library as the fifth tab, settings in Library, visible chat meal drafts, nutrient filters, food-category symbols, a current-period trend figure, a fixed meal-confirmation button, and a simpler empty Diary. Native data models, capture mechanisms and logging transactions remain in place.

See [verification.md](verification.md) for evidence and limits. Browser mockups do not prove native keyboard, VoiceOver, dictation, or real-device interaction behavior.

## Personal photography direction — October 31

Reviewed Kevin’s [homepage](https://kevingreco.me/), [Landscapes](https://kevingreco.me/photography/landscapes), and [Cities](https://kevingreco.me/photography/cities) visually in the browser. The gallery presents 18 landscapes and 13 city photographs. Observed misty forested slopes, pale sky over dark lava, gray water and rocks, a mossy ridgeline, a bird on a fence in hazy warm light, an elk in a muted gold landscape, sun between city buildings, and monochrome upward-looking architectural geometry. No location names are inferred from these images.

The revised directions replace the earlier generic Clear/Pace/Table palettes:

- **Field** (internal `clear`): chalk, fern, slate-green, small ochre accents. Short serif titles echo the homepage; precise rules echo its scientific illustrations. Recommended.
- **Slate** (internal `pace`): graphite and silver-blue, linear structure inspired by architectural framing and gray coastal scenes.
- **Golden** (internal `table`): pale stone, umber and ochre inspired by city sunlight and muted wildlife landscapes.

These are interpreted palettes, not exact color samples. Photos inform the visual language without introducing image backgrounds beneath food amounts. No original photography is copied into the app or redistributed in this artifact. All variants retain the same flows and legible system text for functional content.
