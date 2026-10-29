import test from "node:test";
import assert from "node:assert/strict";
import { runAgent } from "../server/agent.js";
import { defaultTargets, foods } from "../app/data.js";
const dayContext = {
  date: "2026-10-27",
  calorieTarget: 3500,
  targets: defaultTargets,
  entries: [
    {
      quantity: 2,
      food: {
        calories: 100,
        values: { protein: 10, vitC: 20, fiber: 3 },
        partialNutrients: [],
      },
    },
  ],
};
test("food advice receives the selected day actual gaps instead of only chat history", async () => {
  await runAgent({
    messages: [{ role: "user", content: "Which foods help me finish today?" }],
    dayContext,
    database: foods,
    apiKey: "test-only",
    fetchImpl: async (_, options) => {
      const request = JSON.parse(options.body);
      const context = request.messages.find(
        (m) =>
          m.role === "system" && m.content.startsWith("SELECTED_DAY_DATA ("),
      );
      assert.ok(context, "Selected diary context is absent");
      const summary = JSON.parse(context.content.split("\n")[1]);
      assert.equal(summary.date, "2026-10-27");
      assert.equal(summary.calories.consumed, 200);
      assert.equal(summary.calories.remaining, 3300);
      assert.equal(
        summary.nutrients.find((n) => n.id === "vitC").remaining,
        50,
      );
      assert.equal(
        summary.nutrients.find((n) => n.id === "chromium").status,
        "unreported",
      );
      return Response.json({
        choices: [
          { message: { role: "assistant", content: "Here are food options." } },
        ],
      });
    },
  });
});

import { summarizeDay, evaluateChoices } from "../server/day-context.js";
test("reported gaps, partial lower bounds and unknown nutrients are different states", () => {
  const original = structuredClone(dayContext);
  const summary = summarizeDay(dayContext);
  assert.equal(summary.nutrients.find((n) => n.id === "vitC").status, "below");
  assert.equal(summary.nutrients.find((n) => n.id === "vitC").remaining, 50);
  assert.equal(
    summary.nutrients.find((n) => n.id === "chromium").consumed,
    null,
  );
  assert.equal(
    summary.nutrients.find((n) => n.id === "chromium").remaining,
    null,
  );
  const f = {
    ...foods[0],
    values: { ...foods[0].values, vitC: 30, fiber: 10 },
  };
  const result = evaluateChoices(
    [{ foodId: f.id, quantity: 0.5 }],
    new Map([[f.id, f]]),
    summary,
  )[0];
  assert.equal(result.calories, f.calories * 0.5);
  assert.equal(result.nutrients.find((n) => n.id === "vitC").contribution, 15);
  assert.equal(
    result.nutrients.find((n) => n.id === "vitC").remainingAfter,
    35,
  );
  assert.deepEqual(dayContext, original);
  assert.throws(
    () =>
      evaluateChoices(
        [{ foodId: "invented", quantity: 1 }],
        new Map(),
        summary,
      ),
    /Search/,
  );
  assert.throws(
    () => summarizeDay({ ...dayContext, entries: [{ quantity: -1, food: f }] }),
    /Invalid/,
  );
});
test("default Flash requests keep the selected model and provider without a fixed price cap", async () => {
  await runAgent({
    messages: [{ role: "user", content: "I had a burrito" }],
    database: foods,
    apiKey: "test-only",
    fetchImpl: async (_, options) => {
      const request = JSON.parse(options.body);
      assert.equal(request.model, "deepseek/deepseek-v4.1-flash");
      assert.deepEqual(request.provider.only, ["open-inference"]);
      assert.deepEqual(request.provider.quantizations, ["fp4"]);
      assert.equal(request.provider.allow_fallbacks, false);
      assert.equal(Object.hasOwn(request.provider, "max_price"), false);
      return Response.json({
        choices: [
          {
            message: { role: "assistant", content: "Which filling and size?" },
          },
        ],
      });
    },
  });
});
test("suggestion output stops after calculated comparison and cannot invent a combined target claim", async () => {
  const food = {
    ...foods[0],
    values: { ...foods[0].values, vitC: 30, fiber: 10 },
  };
  let requests = 0;
  const tool = (name, args) => ({
    id: String(requests),
    type: "function",
    function: { name, arguments: JSON.stringify(args) },
  });
  const result = await runAgent({
    messages: [
      { role: "user", content: "Which foods help with remaining targets?" },
    ],
    dayContext,
    database: [food],
    apiKey: "test-only",
    fetchImpl: async () => {
      requests++;
      assert.ok(
        requests <= 2,
        "Unnecessary freeform model response after arithmetic",
      );
      return Response.json({
        choices: [
          {
            message: {
              role: "assistant",
              tool_calls: [
                requests === 1
                  ? tool("search_food_database", { query: food.name })
                  : tool("evaluate_food_choices", {
                      choices: [{ foodId: food.id, quantity: 0.5 }],
                    }),
              ],
            },
          },
        ],
      });
    },
  });
  assert.equal(requests, 2);
  assert.equal(result.proposal, null);
  assert.match(result.reply, /15 mg/);
  assert.match(result.reply, /35 mg still left/);
  assert.doesNotMatch(result.reply, /combined|log this/i);
});
