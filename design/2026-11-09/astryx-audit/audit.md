# Nutrient components against Astryx

9 November 2026. [Interactive mockups](index.html). [Chat refusal issue #10](https://github.com/kggreco11/nutrient/issues/10).

## Scope and method

Source review of the native SwiftUI component families in `ios/App/App/NativeApp.swift`, current design contract, and the installed UI Best Practices skill's `references/astryx-components.md`. Compared relevant upstream component contracts at Astryx revision **a9265f169cb0ef358f21928453bd56536dc967ad**. Findings below distinguish source-observed behavior from proposed refinements and runtime checks still needed.

Astryx is a reference for composition and behavior here. Its web foundation uses React and StyleX; the product remains SwiftUI. No React dependency, upstream component code, initializer or changes to runtime agent guidance were introduced. The existing Field palette, Instrument Sans, native navigation, accessible target sizes, nutrition arithmetic and diary/recipe snapshots remain authoritative.

## Findings and mockup decisions

| Priority | Component / source evidence | Finding | Mockup decision / Astryx reference |
| --- | --- | --- | --- |
| High | `NutrientCaptureStyle`, NativeApp.swift:253–270 | The shared style forces maximum width for every caller, including Confirm & log. This conflicts with the user's content-sized action preference. | Separate content-sized actions from intentionally expanded dock actions. Keep a stable hit area and pending size. [Button contract](https://github.com/meta/astryx/blob/a9265f169cb0ef358f21928453bd56536dc967ad/docs/specs/components/Button/Button.spec.md). |
| High | `NativeCustomFood`, NativeApp.swift:2244–2254 | Save is disabled for invalid values, but there is no field-specific explanation for the failing condition. Placeholder-only calories and serving inputs also lose visual labels as they fill. | Persistent labels, visible units and an associated validation message. The mockup shows an invalid energy value and recovery. [Field contract](https://github.com/meta/astryx/blob/a9265f169cb0ef358f21928453bd56536dc967ad/docs/specs/components/Field/Field.spec.md). |
| High | `NativeLibrary`, NativeApp.swift:1996–1998 | `list.isEmpty` displays the same generic message whether nothing is saved or a query/filter has no matches. | Distinct no-match and empty-category messages; Clear search keeps users in the existing workflow. [EmptyState contract](https://github.com/meta/astryx/blob/a9265f169cb0ef358f21928453bd56536dc967ad/docs/specs/components/EmptyState/EmptyState.spec.md). |
| Medium | `NativeQuantityInput` and `NativeSettings`, NativeApp.swift:1252, 2371 | Quantity entry already has a name and unit, but local validation is inconsistent. Target bindings clamp and save as values change; the exact editing consequences need native verification. | Keep direct numeric entry and explicit units. Present local invalid states; evaluate draft/commit behavior before changing autosave. Do not copy small desktop steppers onto the phone. [NumberInput contract](https://github.com/meta/astryx/blob/a9265f169cb0ef358f21928453bd56536dc967ad/docs/specs/components/NumberInput/NumberInput.spec.md). |
| Medium | `NativeChat`, NativeApp.swift:1023–1038, composer:1204–1234 | Pending copy always says it is looking up a meal. Sending disables Send; no response-cancellation handle is exposed in this view. Dictation already has its own stop action. | Specific progress copy, retained message on failure, Retry, and an illustrative Stop response state. Implementing response stop requires real task cancellation, not merely a button. [ChatSendButton contract](https://github.com/meta/astryx/blob/a9265f169cb0ef358f21928453bd56536dc967ad/docs/specs/components/Chat/ChatSendButton.spec.md). |
| Medium | `NativeChatMealDraft`, NativeApp.swift:1330–1387; proposal schemas in `server/agent.js` | An editable review already exists. User-provided nutrition may lack a supported proposal route; see #10. This is a workflow gap to investigate, not an Astryx styling defect. | Mock the desired single-surface review with User-provided provenance, portion edit, meal/date, unknown nutrient disclosure and Confirm & log. Never infer values or claim independent verification. |
| Keep | `FieldSegmentedStyle`, NativeApp.swift:149–159; Library and Trends pickers | Native segments already become menus at accessibility text sizes. This is an appropriate native adaptation. | Retain SwiftUI Picker and its semantics rather than introducing web keyboard rules or truncating labels to match a web component. [SegmentedControl contract](https://github.com/meta/astryx/blob/a9265f169cb0ef358f21928453bd56536dc967ad/docs/specs/components/SegmentedControl/SegmentedControl.spec.md). |
| Keep / refine consistency | `DisclosureGroup` across meal reviews and nutrient averages | The current disclosure pattern already keeps optional complexity out of the main task. | Use a consistent disclosure cue, name and expanded state. Keep editable quantities easy to reach and exact values available. [Collapsible contract](https://github.com/meta/astryx/blob/a9265f169cb0ef358f21928453bd56536dc967ad/docs/specs/components/Collapsible/Collapsible.spec.md). |
| Keep | `DashboardRing`, `NativeMealSummary`, `FieldValuePair`, `NativeTrendPlot` | Product-specific summaries already preserve coverage/calorie distinctions, partial values, stacked accessibility layout and native chart inspection. | Preserve these deep native components. The Trends mockup illustrates a bounded plot and recorded-day context, not an Astryx-based chart replacement. |
| Future verification | Settings feedback, archive feedback and confirmation receipts | Feedback is spread across local strings and app-specific flows; a single reusable feedback contract is not apparent from source review. | Prefer a concise, announced receipt near the action. Introduce Undo only where a real restore operation exists. Do not add decorative notification cards. [Toast contract](https://github.com/meta/astryx/blob/a9265f169cb0ef358f21928453bd56536dc967ad/docs/specs/components/Toast/Toast.spec.md). |

## Component inventory

The review covers buttons/capture actions, icon actions/composer, text and numeric fields, pickers/filters, disclosures, lists/rows, cards/surfaces, messages, loading/error feedback, empty states, meal summaries, progress meters/rings and chart context. Native sheets, confirmation dialogs, camera and speech remain platform-owned. Their physical-device behavior was not audited in this pass. No blanket component replacement is proposed.

## Review scenarios

- **Meal review:** synthetic whole-meal nutrition, editable portion, optional nutrients, meal/date and explicit confirmation. Confirms the intended interaction for #10, without implementing its tool path.
- **Custom food:** visible labels and units, invalid-energy explanation, disabled save and valid recovery. Empty optional calcium remains unknown.
- **Library:** populated list, search no-match, empty category, and clear-search recovery without losing the current task.
- **Trends:** compact controls and bounded illustrative plot, recorded-day denominator, partial composition and values disclosure. Its data is synthetic and is not a real diary analysis.
- **Response states:** loading, stopped, error/retry and ready-draft states. No actual backend request or cancellation occurs.

All buttons keep at least 44 px-equivalent targets. Actions fit their labels; full rows remain selectable. No decorative vertical accent stripes, new bottom tab bar, quiet hours, chart stack, font replacement or generic coaching feed.

## Validation boundary

See [validation.md](validation.md). These are browser references only. Native iPhone implementation, Dynamic Type/VoiceOver behavior, real permission states, task cancellation, model reliability and diary persistence must be verified when changes are implemented. Source review alone cannot certify accessibility or establish the chat bug's root cause.

## Primary references

- [Installed-skill upstream starting point: Meta Astryx](https://github.com/meta/astryx).
- [Astryx component catalog](https://astryx.atmeta.com/components) and [core setup](https://github.com/meta/astryx/blob/a9265f169cb0ef358f21928453bd56536dc967ad/packages/core/README.md).
- Component-specific contracts are linked alongside the findings they informed. They contain documented current-state gaps; using the library as a reference is not evidence that every upstream behavior is ideal or verified in this app.
