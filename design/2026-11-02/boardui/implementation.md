# BoardUI-inspired native refinement

Reference: [BoardUI](https://www.boardui.com/), reviewed November 2, 2026, including the health widgets, public theme/typography tokens and computed Inter font styles. This applies the visual direction in SwiftUI. No React runtime, BoardUI package, paid component source, or web wrapper is added.

## Applied

- Replace the serif headings and rounded metric face with one Inter family. Bundle official Inter 4.1 Regular, Medium, SemiBold and Bold under its included SIL Open Font License.
- Use semantic body/title/label sizes with Dynamic Type. Keep 17 pt body text; do not copy the website’s smaller desktop body size.
- Use medium panel titles, semibold values, regular supporting text, and tabular figures. Navigation titles also use Inter.
- Refine panels to 20 pt corners, achromatic canvas/surface layers, fine borders and minimal contact shadows. Keep the established green nutrient and ochre calorie meaning.
- Refine scan/quick-log controls to 12 pt corners with subtle elevation and a restrained primary fill gradient. Preserve minimum targets and Reduce Motion handling.
- Preserve labeled section boundaries, nutrient contributor links, scan/chat priority, ring alignment, saved meals and chart-selection performance architecture.

## Verification

- Debug Simulator and signed physical-device builds passed; the latter used the generic iOS destination because the paired phone was unavailable.
- Native regression suite passed, including quantity conversion, diary editing, meal saving, gaps, chart selection and contrast checks.
- Native Simulator renders inspected: light/dark populated home, extra-extra-extra-large text, largest accessibility text (stacked), selected trend and chat. Font registration assertions passed during launch. All captures use isolated synthetic data.
- Actual palette text pairs and primary fill-gradient endpoints meet 4.5:1 in the checked set; see [contrast.json](contrast.json). This is not a complete accessibility audit.
- Simulator settings restored to dark/large and app relaunched without fixture arguments. Physical installation is pending reconnection of the iPhone.

## Captures

[Light home](home-light.png) · [Dark home](home-dark.png) · [Large text](home-large-text.png) · [Accessibility text](home-accessibility.png) · [Trends](trends.png) · [Chat](chat.png)
