# Design optional nutrition reports and quiet trend reminders

6 November 2026 · Later feature · [Implementation issue](https://github.com/kggreco11/nutrient/issues/3)

Offer stored weekly/monthly in-app reports under Trends, with optional low-frequency notifications that respect incomplete logging and distinguish personal goals from reference intakes.

## Review artifact

Open [the interactive study](index.html) through a local HTTP server from the repository root. This is a browser reference for native SwiftUI, not shipping UI. All diary and personal-decision data is synthetic. The prototype runs in memory, makes no model calls, and cannot change app settings. Each scenario is directly selectable; the primary actions also connect the flow.

```sh
python3 -m http.server 5198 --bind 127.0.0.1
```

Open `http://127.0.0.1:5198/design/2026-11-06/nutrition-reports/`.

## Design intent

Chart-first reports with high information density and low reading burden. Start with a compact nutrient comparison with chart detail opened separately. Use one short takeaway; let charts carry the quantities and relationships. Explanations, sources, methods and exact values open on demand.

Domain: recorded days, intake, portions, reference intakes, personal targets, evidence provenance, goal decisions. Palette: the existing Field background/surface/ink/secondary/rule/fern assets; food-scale neutrals with fern actions. Signature: a nutrient quantity accompanied by its exact comparison basis and data coverage. Avoided defaults: unsolicited coaching cards, a green ideal-intake band, and a new home notification feed. Use existing Instrument Sans, 17 pt-equivalent body, 4 pt spacing rhythm and at least 44 pt controls; source and personal-decision depth is navigational rather than decorative.

## Report composition

- Keep the initial phone overview to a short takeaway and compact nutrient comparisons. Open an individual nutrient's chart on its own detail screen; the plot is approximately 132 pt-equivalent high at default type rather than a large second chart on the overview.
- A separate All nutrients list covers the full 34-nutrient catalog. The study has synthetic series for four nutrients and explicitly labels other entries as not sampled; magnesium is separately marked partial. Implementation must use the actual diary's full nutrient catalog, not a fixed four-nutrient selection.
- For user-requested exploration, allow all recorded history as an explicit scope, with optional narrower periods. Scheduled reports retain their chosen week/month. Choose observations from deterministic analysis of the available history rather than hardcoding the example's nutrients.
- Use plain-language Published reference / Reference labels. Explain adequate intake in the nutrient's detail view; avoid ambiguous acronym labels such as AI on the chart.
- The detail chart labels the chosen goal and reference; missing dates break the line. Exact values, methodology and original sources remain available through disclosure.
- Partial composition gets a visible status, not a false complete target percentage. A recorded day need not be a complete food log.
- Synthetic means are computed from the same 24 daily values shown in the detail table. All example targets are illustrative personal choices.
- The complete user diary was not accessible during this revision. No real-history findings are claimed, and private diary data is not included in the public PR.

## Behavior

```text
Trends → Reports → period report → nutrient / evidence / contextual chat
Report preferences → Off / Weekly / Monthly → optional notification opt-in
```

- Reports live under Trends → Reports, away from the Today priorities. Store period snapshots with computed data, methodology version, goal/reference versions and evidence links; reports are native in-app content, not PDFs.
- Default proactive reports and notifications to off. Offer weekly or monthly generation, a manual on-demand report, separate push permission, quiet hours, pause, and per-nutrient topic suppression. Refusing push does not block in-app reports.
- Use deterministic aggregations before optional narrative generation. Each finding shows period, recorded-day denominator, nutrient-known/partial counts and comparison basis. Never assume recorded days are complete intake.
- Candidate qualification for review: at least 4 recorded days for a week or 12 for a month, nutrient fully reported on at least 75% of recorded days, and recorded average below 90% of the applicable personal target. These are tunable product thresholds, not clinical criteria; partial records get a data-quality note instead of a confirmed shortfall.
- Cap a report at two salient findings. Weekly/monthly scheduler creates at most one notification per report, with no unchanged shortfall reminders between reports. Apply global/per-topic suppression, deduplicate by report ID and honor chosen quiet hours.
- Below personal target but above a reference is a comparison with a chosen goal, not evidence of deficiency. Do not prioritize a mildly missed custom target over a meaningful source-scoped limit issue.
- Compare source-scoped upper limits with the matching contribution only and show total/food/supplement portions. Partial intake may establish an exceeded limit when known intake alone exceeds it, but cannot establish being below it.
- No diagnosis, treatment inference, forecast, food/supplement recommendation or automated target change. Open-ended follow-up happens only when the user opens chat.
- Reports show the actual goals in effect per day. Mixed-goal periods show daily-normalized comparisons, not one current target pasted across history; no retrospective rewriting.
- Editing/deleting diary data marks affected reports out of date and offers regeneration with a new version. Keep no stale private text after data deletion/export cleanup; report removal and preference changes remain available.
- If insufficient data, store an honest sparse-data report and send no shortfall push. Notification previews are generic by default; no nutrient/health details on a lock screen. Generated narrative is versioned and removable.
- Scheduling, background execution, storage cost and iOS notification behavior need a separate implementation plan and native permission testing; no automation is created by this design task.

## Implementation map

Build on bounded historical context and target history from chat-goals, and reference metadata from nutrient-evidence. Separate deterministic report facts, optional narrative and delivery scheduling. No always-on model analysis.

## Acceptance criteria for implementation

- [ ] The report is understandable from charts and direct labels with at most one short initial takeaway; chart details and prose explanations open separately.
- [ ] All four nutrient selections open a separate detail screen and update its daily series and exact-value table; missing dates break the line, and partial values cannot appear as zero or a complete percentage.
- [ ] Off creates no jobs, model calls or pushes; notification denial still permits report reading/manual generation.
- [ ] Sparse/partial fixtures yield data-quality copy, never zero-filled deficiency claims.
- [ ] Choline custom-target example shows both 80% personal-target comparison and the distinct reference.
- [ ] Deduplication, pause, quiet hours, unchanged-state suppression and per-topic controls prevent repeated nudges.
- [ ] Old reports retain stated period and calculation versions; edited/deleted logs correctly invalidate/remove affected data.
- [ ] Before shipping, verify native Reports navigation, accessibility, empty/loading/failure states and notification permissions.

## Boundaries

No background monitor, push scheduling, PDF, Whoop integration, home feed, model job or shipping report feature in this design PR.

No implementation issue is closed by this design PR. Preserve the diary and historical recipe snapshots. The root AGENTS.md and app-owned assistant workflow remain unchanged. See [validation](validation.md) for the checks actually performed.

## Evidence used to constrain the design

These are reference checks, not a new systematic review. Checked 6 November 2026.

- [NIH ODS choline fact sheet](https://ods.od.nih.gov/factsheets/Choline-HealthProfessional/): adult male AI 550 mg/day; US label DV 550 mg; adult 19+ UL 3,500 mg/day. These are different constructs even when numbers coincide.
- [NIH ODS magnesium fact sheet](https://ods.od.nih.gov/factsheets/magnesium-healthProfessional/): adult 350 mg UL concerns supplemental/medication magnesium, not naturally occurring food magnesium. Source scope must be represented in data and copy.
- [NIH ODS B6 fact sheet](https://ods.od.nih.gov/factsheets/VitaminB6-HealthProfessional/): discusses neuropathy and differing authority limits, including EFSA's 12 mg/day adult UL. A high percentage must not be generalized across B vitamins.
- [NIH ODS FAQ](https://ods.od.nih.gov/HealthInformation/ODS_Frequently_Asked_Questions/): B12 has no established upper limit. The design must not translate that into proof that every dose is safe or useful.

Choline fixture amounts (600/750 mg), personal notes and diary coverage are illustrative, not recommended goals. Prototype claims remain deliberately limited to the reference distinctions above.

## Visual review

<img src="detail.png" width="300" alt="Compact nutrient chart detail with plain-language reference and content-sized action" />


<img src="mockup.png" width="300" alt="nutrition-reports browser interaction reference in light appearance" /> <img src="mockup-large-dark.png" width="240" alt="Narrow larger-text browser reference in dark appearance" />

## Related work

- [Chat goals and historical context](https://github.com/kggreco11/nutrient/issues/1)
- [Nutrient evidence and baselines](https://github.com/kggreco11/nutrient/issues/2)
- [Optional reports](https://github.com/kggreco11/nutrient/issues/3), dependent on historical context and baseline metadata
- [Assistant response preferences](https://github.com/kggreco11/nutrient/issues/4), a later feature with protected app workflows

## Layout refinement · 6 November 2026

The shared design contract now records the user’s preference for content-sized action buttons, text grouped without decorative vertical accent rails, compact phone overviews, and plain-language reference labels. Navigation and selectable data rows retain full-row hit areas. Native implementation and iPhone validation remain outstanding.
