//
//  dev-server.ts
//  server
//
//  Runs the Vercel function locally, so the whole chain (app → proxy →
//  provider) can be checked without a deployment. The handler is the same
//  file Vercel runs - only the plumbing around it differs.
//

import { createServer } from "node:http";
import { handler } from "./api/draft.ts";

const port = Number(process.env.PORT ?? 8732);

const server = createServer((req, res) => {
    const chunks: Buffer[] = [];
    req.on("data", (chunk) => chunks.push(chunk));
    req.on("end", async () => {
        const raw = Buffer.concat(chunks).toString("utf8");
        let body: unknown = raw;
        if (raw.length > 0) {
            try {
                body = JSON.parse(raw);
            } catch {
                body = raw;
            }
        }

        const shim: any = {
            statusCode: 200,
            headers: {} as Record<string, string>,
            body: "",
            status(code: number) {
                shim.statusCode = code;
                return shim;
            },
            json(value: unknown) {
                shim.body = JSON.stringify(value);
                res.writeHead(shim.statusCode, { "Content-Type": "application/json" });
                res.end(shim.body);
                return shim;
            },
            send(value: string) {
                shim.body = value;
                res.writeHead(shim.statusCode, { "Content-Type": "application/json" });
                res.end(value);
                return shim;
            },
            setHeader(name: string, value: string) {
                shim.headers[name] = value;
                return shim;
            },
        };

        await handler({ method: req.method, headers: req.headers, body }, shim);
        if (!res.writableEnded) {
            res.writeHead(shim.statusCode, { "Content-Type": "application/json" });
            res.end(shim.body);
        }
    });
});

server.listen(port, () => {
    console.log(`draft proxy on http://127.0.0.1:${port}/api/draft`);
});
