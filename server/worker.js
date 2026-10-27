import { assets } from "./generated-assets.js";
import { handleApi } from "./http.js";
let database;
const decode = (asset) =>
  Uint8Array.from(atob(asset.body), (c) => c.charCodeAt(0));
async function loadDatabase() {
  return (database ??= new Response(
    new Blob([decode(assets["/data/usda-sr-legacy.json"])])
      .stream()
      .pipeThrough(new DecompressionStream("gzip")),
  ).json());
}
export default {
  async fetch(request, env) {
    const api = await handleApi(request, env, loadDatabase, {
      privateSite: true,
    });
    if (api) return api;
    const path = new URL(request.url).pathname;
    const asset =
      assets[path] ||
      (path === "/" || !path.split("/").at(-1).includes(".")
        ? assets["/index.html"]
        : null);
    if (!asset) return new Response("Not found", { status: 404 });
    const bytes = decode(asset);
    const acceptsGzip = request.headers
      .get("accept-encoding")
      ?.includes("gzip");
    const body = acceptsGzip
      ? bytes
      : new Blob([bytes]).stream().pipeThrough(new DecompressionStream("gzip"));
    return new Response(request.method === "HEAD" ? null : body, {
      headers: {
        "Content-Type": asset.type,
        ...(acceptsGzip ? { "Content-Encoding": "gzip" } : {}),
        Vary: "Accept-Encoding",
        "Cache-Control": path.startsWith("/assets/")
          ? "public,max-age=31536000,immutable"
          : "no-cache",
        "X-Content-Type-Options": "nosniff",
        "Referrer-Policy": "strict-origin-when-cross-origin",
      },
    });
  },
};
