import { readLabel } from "./label.js";
import { runAgent } from "./agent.js";
import { DEFAULT_MODEL, PINNED_PROVIDER } from "./policy.js";
const json = (data, status = 200, headers = {}) =>
  Response.json(data, {
    status,
    headers: { "Cache-Control": "no-store", ...headers },
  });
export async function handleApi(
  request,
  env,
  loadDatabase,
  { local = false, privateSite = false } = {},
) {
  const url = new URL(request.url);
  if (!url.pathname.startsWith("/api/")) return null;
  const origin = request.headers.get("origin");
  const allowedOrigin =
    origin === "capacitor://localhost" || origin === url.origin;
  const cors = allowedOrigin
    ? {
        "Access-Control-Allow-Origin": origin,
        "Access-Control-Allow-Headers":
          "Content-Type, Authorization, OAI-Sites-Authorization",
        "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
        Vary: "Origin",
      }
    : {};
  if (request.method === "OPTIONS")
    return new Response(null, { status: 204, headers: cors });
  if (origin && !allowedOrigin && !local)
    return json({ error: "Origin not allowed." }, 403);
  if (url.pathname === "/api/status")
    return json(
      {
        configured: !!env.OPENROUTER_API_KEY,
        model: env.OPENROUTER_MODEL || DEFAULT_MODEL,
        provider:
          (env.OPENROUTER_MODEL || DEFAULT_MODEL) === DEFAULT_MODEL
            ? PINNED_PROVIDER
            : null,
      },
      200,
      cors,
    );
  if (!["/api/chat", "/api/label"].includes(url.pathname) || request.method !== "POST")
    return json({ error: "Not found." }, 404, cors);
  // Private Sites supply authenticated identity. Native deployments can use a separate
  // app access token; the OpenRouter provider key is never sent to the client.
  const nativeToken =
    env.NUTRIENT_API_TOKEN &&
    request.headers.get("authorization") === `Bearer ${env.NUTRIENT_API_TOKEN}`;
  if (
    !local &&
    !privateSite &&
    !request.headers.get("oai-authenticated-user-id") &&
    !nativeToken
  )
    return json(
      {
        error:
          "Sign in or configure the app access token for this private backend.",
      },
      401,
      cors,
    );
  if (Number(request.headers.get("content-length")) > 250000)
    return json({ error: "Request too large." }, 413, cors);
  try {
    const body = await request.text();
    if (body.length > 250000)
      return json({ error: "Request too large." }, 413, cors);
    const input = JSON.parse(body);
    if (url.pathname === "/api/label") {
      return json(await readLabel({ text: input.text, apiKey: env.OPENROUTER_API_KEY, model: env.OPENROUTER_MODEL || DEFAULT_MODEL }), 200, cors);
    }
    const result = await runAgent({
      messages: input.messages,
      savedFoods: input.savedFoods,
      dayContext: input.dayContext,
      database: await loadDatabase(),
      apiKey: env.OPENROUTER_API_KEY,
      model: env.OPENROUTER_MODEL || DEFAULT_MODEL,
    });
    return json(result, 200, cors);
  } catch (error) {
    return json(
      {
        error: error.status
          ? error.message
          : "Unable to finish this food lookup. Try again or use manual database search.",
      },
      error.status || 502,
      cors,
    );
  }
}
