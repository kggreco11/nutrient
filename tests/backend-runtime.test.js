import test from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { once } from "node:events";
import { createLocalServer } from "../server/dev.js";

test("local development serves API routes without a web frontend", async () => {
  const server = createLocalServer({});
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  try {
    const base = `http://127.0.0.1:${server.address().port}`;
    const status = await fetch(base + "/api/status");
    assert.equal(status.status, 200);
    assert.equal((await status.json()).configured, false);
    const crossOrigin = await fetch(base + "/api/chat", {
      method: "POST",
      headers: { origin: "https://unrelated.example" },
      body: "{}",
    });
    assert.equal(crossOrigin.status, 403);
    const oversized = await fetch(base + "/api/chat", {
      method: "POST",
      body: "x".repeat(250001),
    });
    assert.equal(oversized.status, 413);
    const root = await fetch(base);
    assert.equal(root.status, 404);
    assert.match(await root.text(), /native iOS/);
    const unknown = await fetch(base + "/api/unknown");
    assert.equal(unknown.status, 404);
  } finally {
    server.closeAllConnections();
    await new Promise((resolve) => server.close(resolve));
  }
});

test("hosted API bundle loads its nutrition data without Vite or a web build", async () => {
  execFileSync(process.execPath, ["scripts/build-hosted.mjs"], {
    cwd: new URL("../", import.meta.url),
    stdio: "pipe",
  });
  const { default: worker } = await import("../dist/server/index.js");
  const status = await worker.fetch(
    new Request("https://nutrient.example/api/status"),
    {},
  );
  assert.equal(status.status, 200);
  assert.equal((await status.json()).configured, false);
  const response = await worker.fetch(
    new Request("https://nutrient.example/data/usda-sr-legacy.json"),
    {},
  );
  assert.equal(response.status, 200);
  const foods = await response.json();
  assert.equal(foods.length, 7793);
  assert.ok(foods.some((food) => food.portions?.length));
  const root = await worker.fetch(new Request("https://nutrient.example/"), {});
  assert.equal(root.status, 404);
});
