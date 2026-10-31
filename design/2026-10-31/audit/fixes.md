# Audit fixes — native SwiftUI

All eight findings from design-audit.md are implemented.

| Finding | Change |
| --- | --- |
| Home density | 100 pt rings, one shared progress surface, 52 pt minimum macro targets, explicit home spacing, three shortfall previews |
| Compounded spacing | FieldSpace defines relationships used in shared lists, home, chat and new review/trend components |
| Ingredient form overload | Compact ingredient summaries with one expandable amount/unit editor; fixed confirmation retained |
| Trends priorities | Three largest recorded shortfalls precede expandable complete averages and dated-value tables |
| Large text | Fit-based FieldValuePair stacks labels/values; accessibility-size ring readings use linear progress and unrestricted text |
| Chat scrolling | Container/viewport measurements gate incoming-response follow; Latest message action; explicit user-send/focus jumps; Reduce Motion support; keyboard completion reflow |
| Duplicate add action | Home toolbar now explicitly opens Search foods using a magnifying glass |
| Calorie overage | Exact over-target amount displayed as “X kcal over” |

## Verification

- Debug and Release Simulator builds.
- Native regression checks, including new under/at/over calorie-balance cases and user-versus-incoming chat follow cases.
- Populated home in light and dark: rings, macros and multiple shortfalls visible together.
- Three-ingredient meal review in collapsed and first-expanded states.
- Trends renders priorities before the optional full tables.
- Long product name and nutrient amount checked at the largest accessibility text size.
- Quick log with the software keyboard: composer and latest meal action remain above it.
- Deterministic incoming-response fixtures: earlier messages remain visible while a Latest message action appears; a reader already at the bottom follows the new reply above the keyboard.
- Empty and over-target home states.
- Named color tokens and existing nutrition calculations remain unchanged.

The fixtures are DEBUG-only, use a separate temporary store with preference mirroring disabled, and skip database/network loading. Screenshots show synthetic design data. They do not replace the real diary. Physical iPhone deployment was unavailable during this pass; a full device accessibility/camera/dictation certification is not claimed.

## Repeatable preview commands

After installing the Debug app on a Simulator:

    xcrun simctl launch --terminate-running-process booted com.kggreco11.nutrient --design-fixture populated
    xcrun simctl launch --terminate-running-process booted com.kggreco11.nutrient --design-fixture over
    xcrun simctl launch --terminate-running-process booted com.kggreco11.nutrient --design-fixture empty
    xcrun simctl launch --terminate-running-process booted com.kggreco11.nutrient --design-fixture populated --design-screen review
    xcrun simctl launch --terminate-running-process booted com.kggreco11.nutrient --design-fixture populated --design-screen review --expand-first
    xcrun simctl launch --terminate-running-process booted com.kggreco11.nutrient --design-fixture populated --design-screen trends
    xcrun simctl launch --terminate-running-process booted com.kggreco11.nutrient --design-fixture long --design-screen nutrient
    xcrun simctl launch --terminate-running-process booted com.kggreco11.nutrient --design-fixture reading --design-screen chat
    xcrun simctl launch --terminate-running-process booted com.kggreco11.nutrient --design-fixture follow --design-screen chat

Launch without these arguments to return to the real diary. These render-state checks supplement native model tests; they do not constitute a full touch interaction test.

## Native render evidence

These Simulator captures use synthetic data.

- [Today](after-home.png)
- [Compact meal review](after-review.png)
- [New reply above the keyboard](after-chat-keyboard.png)
- [Reading earlier messages](after-chat-reading.png)
