import { readFile, writeFile, mkdir, rm } from "node:fs/promises";
import { gzipSync } from "node:zlib";
import { build } from "esbuild";
// Only bundle the nutrition dataset; the iOS interface is compiled by Xcode.
await rm("dist", { recursive: true, force: true });
const assets = {};
for (const name of ["usda-sr-legacy.json", "usda-manifest.json"]) {
  assets["/data/" + name] = {
    type: "application/json; charset=utf-8",
    body: gzipSync(
      await readFile(new URL("../data/" + name, import.meta.url)),
    ).toString("base64"),
  };
}
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
  "Built API Worker with bundled nutrition data. No web interface is included.",
);
