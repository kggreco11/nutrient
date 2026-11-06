# Design-study validation

6 November 2026. Design artifacts only; implementation is tracked separately in issue #4.

## Performed

- Headless Google Chrome loaded all 4 selectable scenarios with zero JavaScript page errors.
- 32 layout checks: every scenario at 390 px and 320 px, each with normal/larger text and light/dark appearance. Neither document nor screen content overflowed horizontally. Larger browser text is an approximation for review, not iOS Dynamic Type.
- Local Instrument Sans loaded successfully from the app’s bundled font. Native Field light/dark colors guide the study.
- Editing and Cancel restores the saved instructions. Save updates the in-memory version history. The example preview is static and explicitly labeled; no model instruction-following or security enforcement is claimed.
- Captured a representative light-mode screen and a 320 px larger-text dark-mode screen. Reviewed the representative compositions; screenshots contain synthetic data only.
- Inline JavaScript parsed/executed successfully. Git whitespace checks passed before commit. No runtime app, backend, diary, settings or recipe files changed.

## Not performed / not established

- No SwiftUI feature was implemented. No native iPhone build or native verification of these future flows was performed. Native implementation must meet AGENTS.md and .interface-design/system.md before completion.
- Browser screenshots are design references, not screenshots of the native app. No physical-device, native keyboard/safe-area, full VoiceOver or accessibility certification claim.
- No live model, research retrieval, settings persistence, target migration, history aggregation, push permission, scheduled job or injection-resistance test. Those remain implementation acceptance criteria.
- Prototype steps can be selected directly for review; that reviewer navigation does not represent a production route around proposal consent.

## Compact-layout refinement

- Rechecked all selectable states at 320/390 px with normal/larger text and light/dark appearance; no horizontal overflow or JavaScript page errors.
- Action buttons use their content width; navigation/data rows keep full-row hit targets. Decorative text/card rails were removed.
- Nutrient reference labels use plain language. The reports overview opens chart detail separately, and All nutrients exposes the full catalog with unsampled/partial states.
- No physical-iPhone diary access or real-history analysis occurred. Native implementation/verification is still outstanding.
