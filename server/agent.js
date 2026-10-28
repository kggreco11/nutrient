import { nutrients } from "../app/data.js";
import { searchDatabase } from "../app/food-database.js";
import { lookupBarcode } from "../app/open-food-facts.js";
import { DEFAULT_MODEL, SYSTEM_PROMPT } from "./policy.js";
const functionTool = (name, description, properties, required = []) => ({
  type: "function",
  function: {
    name,
    description,
    parameters: {
      type: "object",
      properties,
      required,
      additionalProperties: false,
    },
  },
});
const num = { type: "number", exclusiveMinimum: 0, maximum: 100 };
const tools = [
  functionTool(
    "search_food_database",
    "Search saved foods first, then USDA foods. Return source records and portion basis. Use short component keywords; refine if ambiguous.",
    { query: { type: "string" }, restaurantOnly: { type: "boolean" } },
    ["query"],
  ),
  functionTool(
    "lookup_barcode",
    "Look up a packaged food in Open Food Facts by its UPC/EAN barcode.",
    { barcode: { type: "string" } },
    ["barcode"],
  ),
  functionTool(
    "request_web_fallback",
    "After database lookup is inadequate, explain why an official public source is needed. Unlocks search and page fetch.",
    { component: { type: "string" }, reason: { type: "string" } },
    ["component", "reason"],
  ),
  functionTool(
    "propose_meal",
    "Return confirmed portions for review only. No diary mutation. Database foods must use an ID returned by a tool. Web foods require a cited official source.",
    {
      components: {
        type: "array",
        minItems: 1,
        maxItems: 25,
        items: {
          type: "object",
          properties: {
            foodId: { type: "string" },
            estimatedFor: {
              type: "string",
              description:
                "User food/product represented by this closest database match; omit for exact matches.",
            },
            matchReason: {
              type: "string",
              description:
                "Brief reason this is a comparable food or preparation.",
            },
            quantity: num,
            webFood: {
              type: "object",
              properties: {
                name: { type: "string" },
                serving: { type: "string" },
                kind: { type: "string", enum: ["food", "supplement"] },
                calories: { type: "number", minimum: 0 },
                sourceUrl: { type: "string" },
                evidence: { type: "string" },
                values: {
                  type: "object",
                  properties: Object.fromEntries(
                    nutrients.map((n) => [
                      n.id,
                      { type: ["number", "null"], minimum: 0 },
                    ]),
                  ),
                  required: nutrients.map((n) => n.id),
                  additionalProperties: false,
                },
              },
              required: [
                "name",
                "serving",
                "kind",
                "calories",
                "sourceUrl",
                "evidence",
                "values",
              ],
              additionalProperties: false,
            },
          },
          required: ["quantity"],
          additionalProperties: false,
        },
      },
    },
    ["components"],
  ),
];
function canonicalUrl(s) {
  try {
    const u = new URL(s);
    if (
      u.protocol !== "https:" ||
      u.username ||
      u.password ||
      u.hostname === "localhost" ||
      /^\d+(?:\.\d+){3}$/.test(u.hostname)
    )
      return null;
    u.hash = "";
    return u.href;
  } catch {
    return null;
  }
}
export function validateProposal(raw, records, citations) {
  if (!Array.isArray(raw) || !raw.length || raw.length > 25)
    throw Error("A meal must have 1–25 components.");
  return raw.map((item, i) => {
    if (
      !Number.isFinite(item.quantity) ||
      item.quantity <= 0 ||
      item.quantity > 100
    )
      throw Error(
        "A consumed portion must be greater than zero and at most 100 source servings.",
      );
    if (item.foodId) {
      const food = records.get(item.foodId);
      if (!food)
        throw Error("Search the database for this food before proposing it.");
      if (item.estimatedFor != null) {
        if (
          typeof item.estimatedFor !== "string" ||
          !item.estimatedFor.trim() ||
          item.estimatedFor.length > 150 ||
          typeof item.matchReason !== "string" ||
          !item.matchReason.trim() ||
          item.matchReason.length > 500 ||
          food.kind === "supplement"
        )
          throw Error(
            "A food estimate needs a product name and comparison reason. Supplement doses require a matching label.",
          );
        return {
          food: {
            ...food,
            id: "estimate-" + crypto.randomUUID(),
            name: item.estimatedFor.trim() + " (estimate)",
            source:
              "Closest match: " +
              food.name +
              " · " +
              (food.source || "Database"),
            evidence: item.matchReason,
            retrievedAt: new Date().toISOString(),
          },
          quantity: item.quantity,
        };
      }
      return { food, quantity: item.quantity };
    }
    const f = item.webFood,
      url = canonicalUrl(f?.sourceUrl);
    if (!f || !url || !citations.has(url))
      throw Error(
        "Web nutrition requires a source URL returned by the internet tools. Fetch the official page and cite it first.",
      );
    if (
      !f.name?.trim() ||
      !f.serving?.trim() ||
      !f.evidence?.trim() ||
      !["food", "supplement"].includes(f.kind) ||
      !Number.isFinite(f.calories) ||
      f.calories < 0 ||
      f.calories > 100000
    )
      throw Error(
        "Web nutrition requires a food name, serving basis, evidence, type and calories.",
      );
    if (
      !nutrients.every(
        (n) =>
          f.values?.[n.id] === null ||
          (typeof f.values?.[n.id] === "number" &&
            Number.isFinite(f.values[n.id]) &&
            f.values[n.id] >= 0 &&
            f.values[n.id] <= 100000),
      )
    )
      throw Error(
        "All nutrients need an explicit number or null in the required units.",
      );
    return {
      food: {
        id: "web-" + crypto.randomUUID(),
        name: f.name.slice(0, 100),
        serving: f.serving.slice(0, 100),
        kind: f.kind,
        calories: f.calories,
        values: f.values,
        source: "Public nutrition source · review required",
        sourceUrl: url,
        evidence: f.evidence.slice(0, 1000),
        retrievedAt: new Date().toISOString(),
        emoji: "◈",
      },
      quantity: item.quantity,
    };
  });
}
export async function runAgent({
  messages,
  savedFoods = [],
  database,
  apiKey,
  model = DEFAULT_MODEL,
  fetchImpl = fetch,
}) {
  if (!apiKey)
    throw Object.assign(
      Error(
        "OpenRouter is not configured. Add OPENROUTER_API_KEY to the server environment. Manual database search, saved meals and scanning remain available.",
      ),
      { status: 503 },
    );
  if (
    !Array.isArray(messages) ||
    !messages.length ||
    messages.length > 16 ||
    !messages.every(
      (m) =>
        ["user", "assistant"].includes(m.role) &&
        typeof m.content === "string" &&
        m.content.length <= 6000,
    )
  )
    throw Object.assign(Error("Invalid conversation."), { status: 400 });
  const library = savedFoods
    .filter(
      (f) =>
        f &&
        typeof f.id === "string" &&
        typeof f.name === "string" &&
        typeof f.serving === "string" &&
        Number.isFinite(f.calories) &&
        nutrients.every(
          (n) =>
            f.values?.[n.id] === null ||
            (Number.isFinite(f.values?.[n.id]) && f.values[n.id] >= 0),
        ),
    )
    .slice(0, 200);
  const history = [{ role: "system", content: SYSTEM_PROMPT }, ...messages],
    records = new Map(),
    citations = new Set(),
    trace = [];
  let searched = false,
    webEnabled = false,
    proposal = null;
  for (let step = 0; step < 7; step++) {
    const available = [
      ...tools,
      ...(webEnabled
        ? [
            {
              type: "openrouter:web_search",
              parameters: {
                engine: "exa",
                max_results: 3,
                max_total_results: 6,
                max_uses: 2,
                search_context_size: "low",
              },
            },
            {
              type: "openrouter:web_fetch",
              parameters: {
                engine: "openrouter",
                max_uses: 3,
                max_content_tokens: 6000,
              },
            },
          ]
        : []),
    ];
    const response = await fetchImpl(
      "https://openrouter.ai/api/v1/chat/completions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
          "X-Title": "Nutrient",
        },
        body: JSON.stringify({
          model,
          messages: history,
          tools: available,
          max_tokens: 3000,
          reasoning: { effort: "none" },
          temperature: 0.1,
        }),
        signal: AbortSignal.timeout(60000),
      },
    );
    if (!response.ok)
      throw Object.assign(
        Error(
          response.status === 401
            ? "OpenRouter rejected the server key."
            : response.status === 402
              ? "OpenRouter needs available credits."
              : response.status === 429
                ? "OpenRouter is busy or rate limited. Try again shortly."
                : "The model service could not complete this request.",
        ),
        { status: 502 },
      );
    const data = await response.json(),
      message = data.choices?.[0]?.message;
    if (!message) throw Error("The model returned no message.");
    for (const a of message.annotations || []) {
      const url = canonicalUrl(a.url_citation?.url);
      if (url) citations.add(url);
    }
    if (!message.tool_calls?.length) {
      if (typeof message.content !== "string" || !message.content.trim()) {
        throw Object.assign(
          Error(
            "The model returned an empty response. Retry your message; your food details have been kept.",
          ),
          { status: 502 },
        );
      }
      return {
        reply: message.content,
        proposal,
        trace,
        model,
        sources: [...citations],
      };
    }
    history.push(message);
    for (const call of message.tool_calls) {
      let output;
      try {
        const args = JSON.parse(call.function.arguments);
        switch (call.function.name) {
          case "search_food_database": {
            if (typeof args.query !== "string" || args.query.length > 200)
              throw Error("Use a short food query.");
            searched = true;
            const local = searchDatabase(library, args.query, { limit: 8 });
            const result = [
              ...local,
              ...searchDatabase(database, args.query, {
                restaurantOnly: !!args.restaurantOnly,
                limit: 12,
              }),
            ];
            for (const f of result) records.set(f.id, f);
            output = {
              foods: result,
              sourceNote:
                "USDA SR Legacy is historical; values per 100 g. Unknowns are null. Saved foods use their listed serving.",
            };
            trace.push({
              tool: "database",
              query: args.query,
              matches: result.length,
            });
            break;
          }
          case "lookup_barcode": {
            const food = await lookupBarcode(args.barcode);
            searched = true;
            records.set(food.id, food);
            output = { food };
            trace.push({ tool: "barcode" });
            break;
          }
          case "request_web_fallback": {
            if (!searched)
              throw Error(
                "Search nutrition databases before requesting internet access.",
              );
            if (!args.component || !args.reason)
              throw Error(
                "Specify the missing component and the database gap.",
              );
            webEnabled = true;
            output = {
              enabled: true,
              instruction:
                "Search official nutrition sources, fetch the source page/PDF, cite it, then propose only explicitly reported nutrition.",
            };
            trace.push({
              tool: "web-fallback",
              component: args.component,
              reason: args.reason,
            });
            break;
          }
          case "propose_meal": {
            if (!searched) throw Error("Search nutrition databases first.");
            proposal = validateProposal(args.components, records, citations);
            output = {
              reviewReady: true,
              instruction:
                "The app will show the proposal and await confirmation. Do not claim the food was logged.",
            };
            break;
          }
          default:
            throw Error("Unsupported tool.");
        }
      } catch (error) {
        output = { error: error.message };
      }
      history.push({
        role: "tool",
        tool_call_id: call.id,
        content: JSON.stringify(output),
      });
    }
    if (proposal)
      return {
        reply:
          "Here is the meal for your review. Confirm the components and quantities before logging.",
        proposal,
        trace,
        model,
        sources: [...citations],
      };
  }
  return {
    reply:
      "I need a little more detail to resolve this reliably. Please specify the food or restaurant, components, preparation and amount.",
    proposal: null,
    trace,
    model,
    sources: [...citations],
  };
}
