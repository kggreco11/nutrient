# Navigation and layout revision

The earlier Field / Slate / Golden proposals varied color and detail more than information architecture. This revision holds the Field palette constant and compares three materially different page structures.

| Direction | Focal point | Capture access | Daily food log | Secondary navigation |
| --- | --- | --- | --- | --- |
| Journal | Two rings and three macro bars | Two large actions above progress | Inline below nutrient shortfalls | Menu and past-days action |
| Capture | Large describe-meal input | Input at the top; Scan and Quick log pinned below | Compact recent-entry ledger | Menu and Full food log |
| Meals | Meal timeline with ingredients | Top action pair plus per-meal Add ingredient | Primary content | Date selector and menu |

None has a bottom tab bar. Chat is part of the logging workflow rather than a permanent destination. Diary becomes the current day’s inline food log, with past days and multi-entry meal selection still accessible.

## Native changes

- Removed TabView. Today is the root NavigationStack.
- Scan barcode opens NativeScanSheet directly from a large home button.
- Quick log presents NativeChat as a sheet, with Done, a drag indicator, and focused composer. Conversation history and drafts remain available.
- Home includes logged entries and an explicit Food log & past days destination. Entry edits and saving a meal from selected diary entries are retained.
- Trends, Library and Settings are reached through the home menu. Trends and Diary use the home navigation stack, preserving native Back navigation.
- Nutrient-gap suggestions and the Trends empty-state action now present the same chat sheet through the existing shared request state.

## Checks

- Native Simulator build succeeds after navigation changes.
- Native home visually inspected: prominent capture buttons, progress summary, no bottom tabs.
- All three proposed homes checked at 375 pt with standard and 200% text: no horizontal body overflow; both capture routes present; no tab bars.
- The interactive viewer supports the existing secondary flows. Browser prototypes do not write diary data or activate a physical camera.
- Simulator pointer control remains unavailable, so a fresh native touch/keyboard/camera pass on an iPhone has not been established by these checks.

Open navigation.html for the latest layout review. The earlier index.html remains an archive of the initial palette proposals.
