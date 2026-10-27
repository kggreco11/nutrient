import { defineConfig, loadEnv } from "vite";
import { readFile } from "node:fs/promises";
import { handleApi } from "./server/http.js";
let database;
export default defineConfig(({ mode }) => ({
  build: { outDir: "dist/client" },
  plugins: [
    {
      name: "nutrient-local-api",
      configureServer(server) {
        const env = { ...loadEnv(mode, process.cwd(), ""), ...process.env };
        server.middlewares.use(async (req, res, next) => {
          if (!req.url?.startsWith("/api/")) return next();
          const chunks = [];
          let size = 0;
          for await (const chunk of req) {
            size += chunk.length;
            if (size > 250000) {
              res.statusCode = 413;
              res.end("Request too large");
              return;
            }
            chunks.push(chunk);
          }
          const request = new Request("http://127.0.0.1:5173" + req.url, {
            method: req.method,
            headers: req.headers,
            ...(req.method === "POST" ? { body: Buffer.concat(chunks) } : {}),
          });
          const response = await handleApi(
            request,
            env,
            async () =>
              (database ??= JSON.parse(
                await readFile("public/data/usda-sr-legacy.json", "utf8"),
              )),
            { local: true },
          );
          res.writeHead(response.status, Object.fromEntries(response.headers));
          res.end(Buffer.from(await response.arrayBuffer()));
        });
      },
    },
  ],
}));
