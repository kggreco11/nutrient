> **Current app setting:** Following the user's explicit selection, the app now pins `deepseek/deepseek-v4.1-flash` to OpenInference FP4, with no provider fallback and maximum quoted rates of $0.00437 input / $1.37 output per million tokens. Live requests returned `provider: OpenInference`. The older alternative-model experiments below are historical, not the current configuration.

# Cheaper OpenRouter models for Nutrient

Checked **27 October 2026, America/Los_Angeles**. Existing app model remains `deepseek/deepseek-v4.1-flash`; no model configuration changed. A follow-up test used a revised validator and prompt as detailed below.

## Correction: the website and catalog show different provider prices

The earlier comparison treated the catalog's single `pricing` object too much like a definitive model price. **The user's screenshot is correct.** The public model-page headline and `/api/v1/models` currently show different provider quotes for the same model. OpenRouter explicitly defines catalog `pricing` as **pricing from the top provider**, rather than a universal or cheapest rate. [Official Models API documentation](https://openrouter.ai/docs/guides/overview/models).

| Same model, different official surface | Input / 1M | Output / 1M | Matching provider endpoint |
|---|---:|---:|---|
| V4.1 Flash: public page headline | **$0.00437** | **$1.37** | OpenInference, `open-inference/fp4` |
| V4.1 Flash: catalog API `pricing` | $0.14 | $0.42 | DeepInfra, `deepinfra/fp8` |
| V4.1 Flash 1017: public page headline | **$0.0151** | **$1.80** | OpenInference, `open-inference/fp4` |
| V4.1 Flash 1017: catalog API `pricing` at recheck | $0.15 | $0.60 | DeepSeek, `deepseek`; includes a time-of-day schedule |

Sources: [Flash public page](https://openrouter.ai/deepseek/deepseek-v4.1-flash), [1017 public page](https://openrouter.ai/deepseek/deepseek-v4.1-flash-1017), [catalog API](https://openrouter.ai/api/v1/models), [Flash endpoint API](https://openrouter.ai/api/v1/models/deepseek/deepseek-v4.1-flash/endpoints), [1017 endpoint API](https://openrouter.ai/api/v1/models/deepseek/deepseek-v4.1-flash-1017/endpoints). All rates are USD per million tokens; raw API token rates were multiplied by one million.

The correspondence is exact: OpenInference's `prompt` and `completion` fields equal the headline pairs above. **These headline input rates are not the endpoint's cache-read rates.** The same endpoint separately quotes cached input at $0.00143/M for Flash and $0.015/M for 1017. This rules out simply explaining the screenshot as “cached input versus uncached input.” The precise algorithm that selects the website headline endpoint was not established in the official documentation reviewed; do not invent a cache blend or effective-usage explanation.

For the user's current price question, compare the same provider and pricing basis: on those OpenInference headline quotes, **1017 is higher on both input and output** than the earlier Flash. The 1017 page describes an October 17 snapshot, whereas the earlier model page describes the September 10 release. That identifies versions; it does not establish comparative food-logging accuracy. No 1017 paid test or model switch was performed.

The app currently leaves provider routing automatic, so a headline or a catalog row is not a guaranteed charged rate. The earlier smoke tests actually reached Wafer and Decart for Flash, with the returned `usage.cost` shown below. OpenRouter documents provider-specific routing and price caps. [Official routing documentation](https://openrouter.ai/docs/guides/routing/provider-selection).

## Historical shortlist from the first catalog check

The following three were cheaper on both input and output **than the $0.14/$0.42 catalog comparison quote**, not cheaper than every Flash endpoint. In particular, none has a lower input rate than the $0.00437 public headline quote. These are archived research candidates, not a fresh recommendation to replace Flash. They support function tools and accept the app's non-reasoning request shape; the actual workflow limitations are recorded below.

| Candidate | Exact model ID | Input / 1M tokens | Output / 1M tokens | Context | Assessment for this app |
|---|---|---:|---:|---:|---|
| DeepSeek V4 Flash 0731 | `deepseek/deepseek-v4-flash-0731` | $0.119 | $0.238 | 1,048,576 | Closest demonstrated swap: produced the correct structured meal review. Text only; loses the current model's image capability. |
| Qwen3.7 Flash | `qwen/qwen3.7-flash` | $0.03 | $0.13 | 1,000,000 | Strong price candidate, with text/image/video input. Test found an optional-field handling problem and extra repair calls; needs tuning before switching. |
| Solar Mini 4 | `upstage/solar-mini4` | $0.05 | $0.20 | 524,288 | Text-only lower-cost alternative. Correct food lookup, but failed to produce the app's meal-review tool call in this test; weakest of these for the current logging workflow. Current price is promotional. |
| Current baseline | `deepseek/deepseek-v4.1-flash` | $0.14 | $0.42 | 1,048,576 | Correct structured review in the matched test. Text and image input. |

Rates, modalities, context, tool support, and reasoning metadata were read directly from the [official live model catalog](https://openrouter.ai/api/v1/models). Qwen's rates rise at **32,000 prompt tokens to $0.10/$0.40**, then at **256,000 to $0.20/$0.80**; the last tier is more expensive than the quoted baseline. [Qwen model page](https://openrouter.ai/qwen/qwen3.7-flash). Solar's page currently marks its $0.05/$0.20 rates **50% off**, so do not assume they are permanent. [Solar model page](https://openrouter.ai/upstage/solar-mini4).

Illustrative uncached workload of 10,000 input + 1,000 output tokens: baseline **$0.00182**, older DeepSeek **$0.001428**, Qwen **$0.00043**, Solar **$0.00070**, using the catalog quotes above. These examples compare those particular quotes only. They do not use the public headline pairs. This calculation holds token counts constant and excludes caching, routing differences, retries, and web-tool fees.

## What the actual app harness did

Used `server/agent.js` → `runAgent`, the bundled **7,793-food USDA database**, existing local OpenRouter credential, no saved custom foods, temperature 0.1 and `reasoning.effort: none`. No diary writes. Paid web research was blocked for this experiment. Two synthetic messages per model:

1. “I ate 150 g cooked roasted chicken breast, skinless, meat only. No added oil, sauce, or other ingredients.”
2. “I ate a burrito.”

The policy and modules were captured at process import; prompt SHA-256 was `d5aefa5a20d7c1256b33f7cf2ce0e570ef95c0a708e5ae6b8c4d487e63bf536b`. The tool schema included optional `estimatedFor` and `matchReason`. Runs occurred approximately 22:00 Pacific on 27 October. Times are one-off wall-clock observations, not latency benchmarks. Costs below are the sum of returned `usage.cost` for each case, including cache effects and the actual routed providers.

| Model | Precise chicken case | Ambiguous burrito case | Returned cost, chicken / burrito |
|---|---|---|---:|
| Current V4.1 Flash | Correct `usda-171477 × 1.5`, **247.5 kcal**; 3 requests, **1.70 s** | Asked fillings/size, no invented proposal; 1 request, **1.29 s** | $0.002907788 / $0.000224190 |
| V4 Flash 0731 | Same correct source and multiplier; 3 requests, **2.44 s** | Asked ingredients/source/size, no invented proposal; 1 request, **1.67 s** | $0.003032200 / $0.000312613 |
| Qwen3.7 Flash | Correct source/multiplier eventually; **6 requests, 7.73 s**; exact match unnecessarily labeled “estimate” | Asked burrito type and size/weight; 1 request, **1.03 s** | $0.000240124 / $0.000025876 |
| Solar Mini 4 | Located correct food, then returned a long nutrient table and asked permission; **no structured review**; 3 requests, **7.43 s** | Asked several missing details, no invented proposal; 1 request, **2.09 s** | $0.000496350 / $0.000150600 |

Qwen repeatedly supplied `estimatedFor: null` for an exact match. At that point, the validator treated present-null as an invalid estimate. After two failed proposal attempts, Qwen supplied a string and created an unnecessary estimate record. Its nutrition and multiplier were correct, but its workflow was poorer than the baseline. An initial Qwen run was stopped at four requests; the table reports the subsequent run with the normal seven-step harness allowance. Solar returned a nutrition answer without using `propose_meal`, so the user could not confirm it through the normal review UI.

Actual routes: current model used Wafer for chicken and Decart for burrito; older DeepSeek used Wafer and DigitalOcean; Qwen used Alibaba; Solar used Upstage. **The older DeepSeek cost slightly more in this tiny routed test despite cheaper catalog rates.** Do not equate a cheaper model card with a guaranteed cheaper completed interaction.

### Follow-up after compatibility fixes

The app developer then made `estimatedFor: null` equivalent to an omitted field and strengthened the instruction to call `propose_meal` immediately once food and quantity are resolved. New prompt SHA-256: `52bf64e4f67a9ddd4d7baf4569e07e1cc0bea76a1d02f538f9c97a4237132b0f`. Repeated only the precise-chicken case once each:

| Model | Result after fixes | Requests / seconds | Returned cost |
|---|---|---|---:|
| Qwen3.7 Flash | Found correct record, printed nutrition and asked permission; **no structured proposal** | 4 / 5.84 s | $0.000326 |
| Solar Mini 4 | Found correct record, printed a long table and asked permission; **no structured proposal** | 4 / 13.41 s | $0.000845 |

These are before/after observations with changed instructions, not a controlled comparison on an identical policy. Null handling alone did not make Qwen's overall workflow dependable. All 14 case runs, including the stopped Qwen attempt, the two rejected GLM probes below, and these follow-ups, returned a combined charge of approximately **$0.008806**, under one cent.

This is a narrow workflow smoke test, not evidence of equal general capability, long-run accuracy, web-source verification quality, or reliability with actual user conversations. None of the burrito cases invented quantities, but several models—including the baseline—asked multi-part questions despite the instruction to ask one concise follow-up.

## Routing and a model excluded from the top three

OpenRouter can route the same model to providers with different prices and caching. Current V4.1 Flash has a Decart endpoint quoted at **$0.09/$0.18**, cheaper on both legs than its catalog comparison rate; older V4 Flash 0731 has a Relace endpoint at **$0.0475/$0.1568** and DeepInfra at **$0.06/$0.18**. These are live endpoint quotes, not guarantees about quality, availability, or the next request's route. [Current-model endpoint API](https://openrouter.ai/api/v1/models/deepseek/deepseek-v4.1-flash/endpoints), [older-model endpoint API](https://openrouter.ai/api/v1/models/deepseek/deepseek-v4-flash-0731/endpoints). Provider selection supports price limits and explicit routing, so keeping the model that is working and controlling routing is also worth considering. [Official routing documentation](https://openrouter.ai/docs/guides/routing/provider-selection).

**GLM 5.3 Flash** (`z-ai/glm-5.3-flash`) has attractive catalog rates of **$0.0454/$0.0737** and tool support, but its mandatory reasoning conflicts with this harness's `effort: none`. Both case requests failed immediately with HTTP 400: reasoning cannot be disabled. It is not a direct replacement under the current request parameters. [Official model catalog](https://openrouter.ai/api/v1/models), [GLM page](https://openrouter.ai/z-ai/glm-5.3-flash).

**Decision:** Keep V4.1 Flash as the default while testing. V4 Flash 0731 is the only alternative here demonstrated to complete the structured food-log review without repair in this small test. Qwen is the most compelling low-price candidate for further workflow tuning; Solar is a weaker third option. The evidence does not support calling all three equally capable or ready replacements. No model was changed automatically.
