import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";
import { handleApi } from "./http.js";

// Local development is loopback-only; hosted requests keep their existing authentication.
export function createLocalServer(env = process.env) {
  let database;
  return createServer(async (incoming, outgoing) => {
    try {
      const base = `http://127.0.0.1:${incoming.socket.localPort}`;
      if (incoming.headers.origin && incoming.headers.origin !== base) {
        incoming.resume();
        outgoing.writeHead(403);
        outgoing.end("Origin not allowed");
        return;
      }
      if (Number(incoming.headers["content-length"]) > 250000) {
        incoming.resume();
        outgoing.writeHead(413);
        outgoing.end("Request too large");
        return;
      }
      const chunks = [];
      let size = 0;
      for await (const chunk of incoming) {
        size += chunk.length;
        if (size > 250000) {
          outgoing.writeHead(413);
          outgoing.end("Request too large");
          return;
        }
        chunks.push(chunk);
      }
      const request = new Request(new URL(incoming.url, base), {
        method: incoming.method,
        headers: incoming.headers,
        ...(!["GET", "HEAD"].includes(incoming.method)
          ? { body: Buffer.concat(chunks) }
          : {}),
      });
      const response =
        (await handleApi(
          request,
          env,
          () =>
            (database ??= readFile(
              new URL("../data/usda-sr-legacy.json", import.meta.url),
              "utf8",
            ).then(JSON.parse)),
          { local: true },
        )) ??
        new Response("Nutrient's interface is the native iOS app.", {
          status: 404,
        });
      outgoing.writeHead(response.status, Object.fromEntries(response.headers));
      outgoing.end(
        incoming.method === "HEAD"
          ? undefined
          : Buffer.from(await response.arrayBuffer()),
      );
    } catch {
      outgoing.writeHead(500, {
        "Content-Type": "application/json",
        "Cache-Control": "no-store",
      });
      outgoing.end(
        JSON.stringify({ error: "Unable to process this request." }),
      );
    }
  });
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  const port = Number(process.env.PORT || 8787);
  createLocalServer().listen(port, "127.0.0.1", () => {
    console.log(`Nutrient API: http://127.0.0.1:${port}/api/status`);
  });
}
