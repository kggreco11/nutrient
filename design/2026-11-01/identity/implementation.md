# Native visual identity implementation

Implemented November 1, 2026, following the [award-reference brief](../apple-awards-and-direction.md).

## Direction

A precise nutrition journal: warm neutral light surfaces, charcoal dark surfaces, readable figures and an original N mark. Color carries actions and progress; neutral structure carries food records and controls. The references informed hierarchy and restraint rather than copied layouts or artwork.

## Implemented

- Home is an open, centered composition with a 20 pt phone gutter and 600 pt maximum content width. Two thin 104 pt rings, three 52 pt macro rows and three preview shortfalls remain visible together at standard type.
- Capture actions use 54 pt minimum height, 14 pt corner radii, explicit outline/solid hierarchy and brief press feedback. Reduce Motion removes the press scale and progress movement.
- Numeric figures are stronger than units and supporting labels. Section titles use serif type sparingly; other pages use native navigation titles.
- Food records use a plain ledger treatment with separate quantities, energy and edit affordances. Tap to edit, long-press for edit/remove on home, and native diary swipe actions remain available.
- The coverage ring opens the full daily-target breakdown. Detailed nutrient/food contributor access remains available.
- Neutral library rows replace repeated decorative green icon tiles. Ingredient review keeps reported nutrition, amount/unit editing, sources and fixed confirmation.
- Charts use neutral readout figures and subtle bar corners. Their isolated selection state and per-period updates remain intact; no data interpolation or smoothing was added.
- The original N mark is used in the wordmark and an opaque 1024 px app icon. [mark.svg](mark.svg) is the vector source; `scripts/render-brand-icon.py` regenerates the icon using Pillow. The icon is ready to build without running the script.

## Verification

- Debug Simulator, Debug physical iPhone and Release Simulator builds passed.
- Native regression checks passed, including chart selection, logging/editing, saved meals, quantity conversions, persistence and light/dark accent checks.
- Actual named-token contrast checked for primary, secondary, accent, energy and error text on canvas and surface, plus primary button labels. The minimum ratio is 5.32:1; see [contrast.json](contrast.json). This is not a complete accessibility certification.
- Populated light/dark home, largest accessibility-size home, empty home, selected chart and expanded ingredient review rendered in native Simulator. The largest text layout stacks controls and replaces rings with text/linear progress so content can grow and scroll.
- Simulator captures are synthetic, isolated DEBUG fixtures; real diary data was not replaced. The new build was installed on the paired iPhone; automatic launch was blocked while it was locked. Full physical touch, camera and VoiceOver certification is not claimed.

## Captures

- [Light home](home-light.png)
- [Dark home](home-dark.png)
- [Accessibility text](home-accessibility.png)
- [Chart](trends-dark.png)
- [Ingredient review](review-dark.png)
