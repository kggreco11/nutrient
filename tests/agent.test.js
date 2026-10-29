import test from "node:test";
import assert from "node:assert/strict";
import { runAgent, validateProposal } from "../server/agent.js";
import { handleApi } from "../server/http.js";
import { DEFAULT_MODEL, PINNED_PROVIDER } from "../server/policy.js";
import { foods, nutrients } from "../app/data.js";
const call = (name, args) => ({
  id: crypto.randomUUID(),
  type: "function",
  function: { name, arguments: JSON.stringify(args) },
});
const response = (message) =>
  Response.json({ choices: [{ message: { role: "assistant", ...message } }] });
test("model receives database tools first and produces a database-backed review without mutating logs", async () => {
  let turn = 0;
  const requests = [];
  const f = foods[0];
  const fetchImpl = async (_, init) => {
    const body = JSON.parse(init.body);
    requests.push(body);
    turn++;
    return turn === 1
      ? response({
          tool_calls: [call("search_food_database", { query: "oats" })],
        })
      : response({
          tool_calls: [
            call("propose_meal", {
              components: [{ foodId: f.id, quantity: 1.5 }],
            }),
          ],
        });
  };
  const result = await runAgent({
    messages: [{ role: "user", content: "I ate oats" }],
    database: foods,
    apiKey: "test-only",
    fetchImpl,
  });
  assert.equal(result.proposal[0].quantity, 1.5);
  assert.equal(result.proposal[0].food.calories, 150);
  assert.equal(requests[0].model, DEFAULT_MODEL);
  assert.ok(!requests[0].tools.some((t) => t.type === "openrouter:web_search"));
  assert.equal(result.trace[0].tool, "database");
});
test("web tools are unlocked only after a database lookup and a fallback request", async () => {
  let turn = 0;
  const requests = [];
  const fetchImpl = async (_, init) => {
    const body = JSON.parse(init.body);
    requests.push(body);
    turn++;
    if (turn === 1)
      return response({
        tool_calls: [
          call("request_web_fallback", {
            component: "new meal",
            reason: "missing",
          }),
        ],
      });
    if (turn === 2) {
      assert.ok(
        body.messages.at(-1).content.includes("Search nutrition databases"),
      );
      return response({
        tool_calls: [
          call("search_food_database", { query: "no-matching-food" }),
        ],
      });
    }
    if (turn === 3)
      return response({
        tool_calls: [
          call("request_web_fallback", {
            component: "new meal",
            reason: "no matches",
          }),
        ],
      });
    return response({
      content: "Which components and portion size did you have?",
    });
  };
  const result = await runAgent({
    messages: [{ role: "user", content: "A restaurant meal" }],
    database: foods,
    apiKey: "test-only",
    fetchImpl,
  });
  assert.ok(!requests[2].tools.some((t) => t.type === "openrouter:web_search"));
  assert.ok(requests[3].tools.some((t) => t.type === "openrouter:web_search"));
  assert.equal(result.proposal, null);
  assert.match(result.reply, /Which components/);
});
test("proposals reject unsearched IDs, unsupported source URLs, and missing data", () => {
  assert.throws(() =>
    validateProposal(
      [{ foodId: "invented", quantity: 1 }],
      new Map(),
      new Set(),
    ),
  );
  const food = {
    name: "Test",
    serving: "1 serving",
    kind: "food",
    calories: 100,
    sourceUrl: "https://example.com/nutrition",
    evidence: "100 calories per serving",
    values: Object.fromEntries(nutrients.map((n) => [n.id, null])),
  };
  assert.throws(() =>
    validateProposal([{ webFood: food, quantity: 1 }], new Map(), new Set()),
  );
  const proposal = validateProposal(
    [{ webFood: food, quantity: 1 }],
    new Map(),
    new Set([food.sourceUrl]),
  );
  assert.equal(proposal[0].food.values.vitD, null);
  assert.ok(proposal[0].food.retrievedAt);
  assert.throws(() =>
    validateProposal(
      [{ webFood: { ...food, sourceUrl: "javascript:alert(1)" }, quantity: 1 }],
      new Map(),
      new Set(),
    ),
  );
});
test("missing credentials fails clearly without making any model request", async () => {
  let called = false;
  await assert.rejects(
    () =>
      runAgent({
        messages: [{ role: "user", content: "hello" }],
        database: [],
        fetchImpl: async () => {
          called = true;
        },
      }),
    (e) => e.status === 503,
  );
  assert.equal(called, false);
});
test("model errors do not expose provider responses or credentials", async () => {
  await assert.rejects(
    () =>
      runAgent({
        messages: [{ role: "user", content: "hello" }],
        database: [],
        apiKey: "test-secret",
        fetchImpl: async () => new Response("test-secret", { status: 401 }),
      }),
    (e) => !e.message.includes("test-secret") && e.message.includes("rejected"),
  );
});
test("API checks authentication and cross-origin access before model execution", async () => {
  const load = async () => [];
  const req = new Request("https://app.example/api/chat", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ messages: [{ role: "user", content: "hello" }] }),
  });
  assert.equal((await handleApi(req, {}, load)).status, 401);
  const r = await handleApi(req, {}, load, { local: true });
  assert.equal(r.status, 503);
  const wrong = new Request("https://app.example/api/chat", {
    method: "POST",
    headers: { origin: "https://evil.example" },
    body: "{}",
  });
  assert.equal(
    (await handleApi(wrong, {}, load, { privateSite: true })).status,
    403,
  );
  const status = await handleApi(
    new Request("https://app.example/api/status"),
    { OPENROUTER_API_KEY: "never-return-this" },
    load,
  );
  assert.deepEqual(await status.json(), {
    configured: true,
    model: DEFAULT_MODEL,
    provider: PINNED_PROVIDER,
  });
});
test("empty provider output is a retryable service error, never a fabricated clarification", async () => {
  await assert.rejects(
    runAgent({
      messages: [{ role: "user", content: "150g roasted chicken breast" }],
      database: foods,
      apiKey: "test-only",
      fetchImpl: async () =>
        Response.json({
          choices: [
            {
              finish_reason: "length",
              message: { role: "assistant", content: "" },
            },
          ],
        }),
    }),
    /empty|complete|response/i,
  );
});
test("closest product estimates retain retrieved nutrition and provenance without changing the original record", () => {
  const food = foods[0];
  const original = structuredClone(food);
  const proposal = validateProposal(
    [
      {
        foodId: food.id,
        quantity: 1.5,
        estimatedFor: "Neighborhood oat porridge",
        matchReason:
          "Same rolled oats prepared in water; user supplied the weight.",
      },
    ],
    new Map([[food.id, food]]),
    new Set(),
  );
  assert.match(proposal[0].food.id, /^estimate-/);
  assert.match(proposal[0].food.name, /estimate/);
  assert.match(proposal[0].food.source, /Closest match/);
  assert.deepEqual(proposal[0].food.values, food.values);
  assert.equal(proposal[0].quantity, 1.5);
  assert.deepEqual(food, original);
  assert.throws(
    () =>
      validateProposal(
        [{ foodId: food.id, quantity: 1, estimatedFor: "Other food" }],
        new Map([[food.id, food]]),
        new Set(),
      ),
    /reason/,
  );
});
test("nullable estimate metadata on an exact match does not cause a tool retry or invent an estimate", () => {
  const food = foods[0];
  const result = validateProposal(
    [{ foodId: food.id, quantity: 1, estimatedFor: null, matchReason: null }],
    new Map([[food.id, food]]),
    new Set(),
  );
  assert.equal(result[0].food.id, food.id);
  assert.equal(result[0].food, food);
});

test("price-filtered endpoint errors explain the cap without suggesting retries or exposing upstream text", async () => {
  await assert.rejects(
    runAgent({
      messages: [{ role: "user", content: "I ate an apple" }],
      database: foods,
      apiKey: "test-only",
      fetchImpl: async () => Response.json({ error: { message: "No endpoints found that satisfy the max price for this request. secret-debug-value" } }, { status: 404 }),
    }),
    (error) => {
      assert.match(error.message, /price cap/i);
      assert.doesNotMatch(error.message, /try again|secret-debug-value/i);
      return true;
    },
  );
});

test("endpoint outages do not claim that the price cap was exceeded", async () => {
  await assert.rejects(
    runAgent({
      messages: [{ role: "user", content: "I ate an apple" }],
      database: foods,
      apiKey: "test-only",
      fetchImpl: async () => Response.json({ error: { message: "No endpoints found for this model" } }, { status: 404 }),
    }),
    (error) => {
      assert.match(error.message, /unavailable/i);
      assert.doesNotMatch(error.message, /price/i);
      return true;
    },
  );
});
