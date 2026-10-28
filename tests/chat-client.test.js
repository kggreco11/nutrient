import test from "node:test";
import assert from "node:assert/strict";
import { sendChat } from "../app/chat-client.js";
const payload = {
  messages: [{ role: "user", content: "I ate a burrito" }],
  savedFoods: [],
};
test("web chat sends the conversation and preserves private session authentication", async () => {
  const response = await sendChat(payload, {
    fetchImpl: async (url, options) => {
      assert.equal(url, "/api/chat");
      assert.equal(options.credentials, "include");
      assert.deepEqual(JSON.parse(options.body), payload);
      return Response.json({ reply: "Which fillings?", proposal: null });
    },
  });
  assert.equal(response.reply, "Which fillings?");
});
test("expired private session has an actionable error instead of a JSON error", async () => {
  await assert.rejects(
    sendChat(payload, {
      fetchImpl: async () =>
        new Response("Sign in", {
          status: 401,
          headers: { "Content-Type": "text/html" },
        }),
    }),
    /Sign in/,
  );
  await assert.rejects(
    sendChat(payload, {
      fetchImpl: async () => Response.json({}, { status: 401 }),
    }),
    /Reconnect/,
  );
});
