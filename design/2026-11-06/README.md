# Approved native direction

The workflow proposal was approved on 6 November 2026. Implementation is native SwiftUI. Durable rules and completion checks live in [the design contract](../../.interface-design/system.md), loaded through the repository AGENTS.md.

## Typography comparison

Instrument Sans: selected for the native implementation. Compact, slightly distinctive forms work for daily totals, food names and ingredient amounts while keeping the surrounding chrome quiet.

Manrope: a softer geometric alternative. Good numeric presence, but its rounder tone made the journal feel less exact in this composition.

Public Sans: the most utilitarian option. Clear and sturdy, with less distinction from the previous neutral interface.

These are visual judgments from the same local Today composition at the same type sizes, not measured accessibility outcomes. Inter was retained in the comparison as the prior baseline. Local review at http://127.0.0.1:5196/ has a typeface selector; it remains a disposable browser study rather than the shipping app.

Font sources: [Instrument Sans](https://github.com/google/fonts/tree/main/ofl/instrumentsans), [Manrope](https://github.com/google/fonts/tree/main/ofl/manrope), [Public Sans](https://github.com/google/fonts/tree/main/ofl/publicsans). The app bundles only Instrument Sans; source and derivation are recorded in ios/App/App/Fonts/README.md.

Adapted review method: Unslop by Damir Sokolovsky (@heydamir), https://heydamir.design/unslop, CC BY 4.0; UI Best Practices and interface-design informed the workflow and interaction checks.
