# Nutrition assistant contract

`server/policy.js` is the runtime system prompt. `server/agent.js` is the bounded tool loop; `server/http.js` is the server endpoint. Conversation interpretation is performed by the configured LLM. There is no parallel rule-based parser.

The default provider is OpenRouter with model `deepseek/deepseek-v4.1-flash`. Only server environment configuration can change the model/key. The app sends user/assistant conversation text and the active saved-food library, not the entire diary. History is limited to the latest 12 text messages. A turn permits at most seven model requests, each with an output-token ceiling. The model has no write tool or access to environment values.

## Lookup and clarification

The database tool searches the saved library before the bundled USDA SR Legacy dataset. Search outputs contain immutable IDs, serving bases, provenance and nutrition values. The model can refine database keywords; it must ask users about materially different preparations, brands, components or amounts instead of silently choosing.

Barcode lookup uses Open Food Facts and keeps absent fields null. Restaurant coverage is provider dependent. Current branded recipes should not be silently substituted with historical USDA or generic approximations.

`request_web_fallback` fails until at least one database lookup has occurred. Once enabled, the next model call can use OpenRouter's web-search server tool and page/PDF fetch tool. Search is limited to three results per call/two searches, and page fetch to three calls/6,000 content tokens per request. The system prompt requires official sources and fetching the underlying page before nutrition extraction. These are model/provider behaviors; only a live evaluation can establish reliable adherence, and a missing key prevents that evaluation.

## Proposal, provenance and unknowns

A proposed database component must refer to an ID actually returned by a tool in that turn. Its nutrient numbers come from the database, not the model. The consumed quantity is a multiplier of the source serving and is validated as positive and at most 100.

A proposed web component must supply a safe HTTPS source URL present in returned citation annotations, an evidence excerpt, serving description, food/supplement type, explicit calories and all tracked nutrient fields as nonnegative numbers or null. It receives a retrieval timestamp. Citation membership prevents arbitrary uncited URLs but does not prove that an extraction is correct. UI review remains required. When the provider does not return usable citations, the harness rejects the sourced-food proposal and asks for a grounded source rather than trusting it.

Unreported nutrients are unknown. Never fill missing micronutrients from model memory or infer them from macros. Meals sum known contributions and retain flags for incomplete nutrients. Calculations and target comparisons are app code, not LLM arithmetic.

The app displays components, servings, sources and data gaps. Only the explicit confirmation form writes entries. Supplements are logged as supplements. Optional meal saving snapshots food components for reuse; it does not turn supplements into foods.

## Privacy and execution limits

Secrets remain server-only. Untrusted retrieved pages and food descriptions cannot authorize actions, change instructions or reveal secrets. There is no arbitrary network-fetch client tool, shell tool, filesystem tool or mutation tool. Provider web tools handle public-page retrieval. HTTP requests have input-size, role and content-length checks; cross-origin access is restricted. Private Sites authentication remains the hosting boundary. Standalone deployments must preserve authentication.

Model tokens and web tools consume credits. No requests run while the app is idle, and Trends never calls the model. No ongoing EDA, coaching, predictions, background monitoring or schedules are part of this version.

Automated tests use mocked OpenRouter responses to verify tool order, lookup-before-web gating, proposal provenance, error handling and no-key behavior. They do not prove model quality or live internet extraction. A configured provider key and a physical iPhone are needed to finish live assistant, camera and dictation verification.
