# Saved meal details and editing

## Behavior

Library meals open a detail sheet with per-meal energy/macros and each ingredient’s amount. Expand an ingredient to inspect its nutrient contribution. Edit opens a staged recipe editor for the name, quantities/units, ingredient addition and removal. Save recalculates all nutrients and stores the updated recipe; Cancel discards edits. Log meal remains available from details. Library swipe-to-edit also supports meals.

Edited recipes receive a new food identity while the old version is archived. Historical diary entries and nested meals keep the original nutrition. New component records include full food snapshots (energy, nutrients, measures and metadata) alongside the legacy fields, preserving backward decoding compatibility.

Legacy components recover an exact name/serving/source match from saved foods or the bundled database, retaining their saved nutrient values. If component energy cannot be recovered, the editor offers an explicit calories field. A formerly complete meal cannot silently be replaced with missing-energy totals.

## Checks

- Native regression suite passed: ingredient snapshot persistence, legacy recovery, changed quantities/removal and recomputation, historical diary preservation, invalid quantities, missing energy protection and rollback after failed disk writes; all prior native checks also passed.
- Debug Simulator and signed device builds passed.
- In the actual native Simulator, opened a library meal, expanded an ingredient, opened the library Edit action, and changed bread from 64 g to 96 g. The live energy total changed from 347 to 432 kcal and protein from 17 to 21 g. All data was an isolated DEBUG fixture.
- Detail and editor captures: [details.png](details.png), [ingredient.png](ingredient.png), [editor.png](editor.png).
- Coordinate interaction with Simulator navigation controls remains unavailable in the computer-use tool. Save/persistence behavior is covered by the real store regression checks rather than claimed as a complete touch-driven UI test.

The paired iPhone disconnected during the pre-install backup attempt. Physical installation is pending reconnection; no real diary or library data was modified. Simulator was returned to its normal root without fixture arguments.
