import { readFile, writeFile, mkdir, readdir, rm } from "node:fs/promises";
import { gzipSync } from "node:zlib";
import { extname, join } from "node:path";
import { build } from "esbuild";
const types = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
};
const assets = {};
async function walk(dir) {
  for (const file of await readdir(dir, { withFileTypes: true })) {
    if (["server", ".openai"].includes(file.name)) continue;
    const path = join(dir, file.name);
    if (file.isDirectory()) await walk(path);
    else
      assets["/" + path.slice("dist/client/".length)] = {
        type: types[extname(file.name)] || "application/octet-stream",
        body: gzipSync(await readFile(path)).toString("base64"),
      };
  }
}
await walk("dist/client");
const generated = "server/generated-assets.js";
await writeFile(
  generated,
  "export const assets=" + JSON.stringify(assets) + ";",
);
try {
  await mkdir("dist/server", { recursive: true });
  await build({
    entryPoints: ["server/worker.js"],
    outfile: "dist/server/index.js",
    bundle: true,
    format: "esm",
    platform: "browser",
    target: "es2022",
    minify: true,
  });
  await mkdir("dist/.openai", { recursive: true });
  await writeFile(
    "dist/.openai/hosting.json",
    await readFile(".openai/hosting.json"),
  );
} finally {
  await rm(generated, { force: true });
}
console.log(
  "Built hosted Worker with compressed static assets and server-only OpenRouter endpoint.",
);
