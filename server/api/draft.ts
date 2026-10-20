//
//  draft.ts
//  server/api
//
//  A Vercel function: an OpenAI-compatible chat-completions proxy for Groq.
//
//  Why it exists: the apps speak the OpenAI chat-completions dialect (that
//  is the wire protocol Core owns - AIDraftRemoteProtocol), and Groq speaks
//  it too. So the function is a pass-through that adds the two things the
//  app must not carry: the provider key and the model.
//
//  The answer goes back unchanged. The app's parser knows this envelope
//  (choices[0].message.content), so nothing in the client changes when the
//  provider behind it changes.
//
//  The function never logs the key, the prompt or the answer: the note text
//  is the user's, and the proxy sees all of it.
//
//  The daily counter lives in this file on purpose: Vercel transpiles the
//  files of `api/` one by one and does not bundle them, so an import of a
//  file outside `api/` would be left dangling in the deployment.
//

const DEFAULT_GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";
const DEFAULT_MODEL = "llama-3.3-70b-versatile";
const DEFAULT_MAX_TOKENS = 700;
const DEFAULT_DAILY_LIMIT = 50;

/**
 * The counter of last resort: the process-local one. It is used when the
 * store is unreachable, so a broken store costs the cap its reach but not
 * the proxy its answers.
 */
const fallbackCounter = memoryCounter();

function clientKey(req: { headers?: Record<string, unknown> }): string {
    const forwarded = req.headers?.["x-forwarded-for"];
    const raw = Array.isArray(forwarded) ? forwarded[0] : forwarded;
    const ip = typeof raw === "string" ? raw.split(",")[0].trim() : "";
    return ip || "unknown";
}

function parseBody(body: unknown): Record<string, unknown> | null {
    if (typeof body === "string") {
        try {
            const parsed = JSON.parse(body);
            return parsed && typeof parsed === "object" ? (parsed as Record<string, unknown>) : null;
        } catch {
            return null;
        }
    }
    if (body && typeof body === "object") return body as Record<string, unknown>;
    return null;
}

type Message = { role: string; content: string };

/** Only the fields the provider understands, with the sizes capped. */
function sanitizeMessages(value: unknown): Message[] {
    if (!Array.isArray(value)) return [];
    return value
        .filter((item): item is { role?: unknown; content?: unknown } =>
            !!item && typeof item === "object",
        )
        .map((item) => ({
            role: typeof item.role === "string" ? item.role : "user",
            content: typeof item.content === "string" ? item.content.slice(0, 8000) : "",
        }))
        .filter((message) => message.content.length > 0)
        .slice(0, 8);
}

/**
 * Whether the client is still under its daily cap.
 *
 * The count comes from the deployment's counter - a store, when it has one -
 * so the cap holds between instances. When the store is unreachable the
 * count falls back to the process-local one: the cap then holds as well as
 * it used to, which is less than promised, but the answer still goes out.
 */
async function withinDailyLimit(counter: DailyCounter, client: string, limit: number): Promise<boolean> {
    try {
        const count = await counter.increment(client);
        // The count and the limit, never the note: this is the whole audit
        // trail the proxy keeps.
        console.log(`daily count=${count} limit=${limit}`);
        return count <= limit;
    } catch {
        console.warn("the daily counter is unreachable, counting in memory");
        const count = await fallbackCounter.increment(client);
        return count <= limit;
    }
}

export function createHandler(counter: DailyCounter) {
    return async function handler(req: any, res: any): Promise<void> {
        if (req.method !== "POST") {
            res.setHeader("Allow", "POST");
            res.status(405).json({ error: "method_not_allowed" });
            return;
        }

        const apiKey = process.env.GROQ_API_KEY;
        if (!apiKey) {
            res.status(503).json({ error: "provider_unavailable" });
            return;
        }

        const body = parseBody(req.body);
        const messages = sanitizeMessages(body?.messages);
        if (messages.length === 0) {
            res.status(400).json({ error: "bad_request" });
            return;
        }

        const dailyLimit = Number(process.env.DAILY_LIMIT ?? DEFAULT_DAILY_LIMIT);
        if (dailyLimit > 0 && !(await withinDailyLimit(counter, clientKey(req), dailyLimit))) {
            res.status(429).json({ error: "rate_limited" });
            return;
        }

        // The client may name a model; the proxy pins its own. The price of the
        // answer is the server's decision, not the caller's - unless the
        // deployment opted into letting clients choose, which only the model
        // comparison tool needs.
        const clientModel = process.env.GROQ_ALLOW_CLIENT_MODEL === "1"
            ? (typeof body?.model === "string" ? body.model : "")
            : "";
        const payload = {
            model: clientModel || process.env.GROQ_MODEL || DEFAULT_MODEL,
            messages,
            temperature: typeof body?.temperature === "number" ? body.temperature : 0.7,
            max_tokens: Number(process.env.GROQ_MAX_TOKENS ?? DEFAULT_MAX_TOKENS),
        };

        let upstream: Response;
        try {
            upstream = await fetch(process.env.GROQ_URL || DEFAULT_GROQ_URL, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    Authorization: `Bearer ${apiKey}`,
                },
                body: JSON.stringify(payload),
            });
        } catch {
            res.status(502).json({ error: "provider_unavailable" });
            return;
        }

        // Passed through as it is: the app parses this envelope, and the status
        // tells it whether the provider was rate limited (429) or simply failed.
        const text = await upstream.text();
        res.status(upstream.status);
        res.setHeader("Content-Type", "application/json");
        res.send(text);
    };
}

export const handler = createHandler(counterFromEnv());

export default handler;

// MARK: - The daily counter
//
// How many answers one client address got today.
//
// The daily cap has to hold between serverless instances: they come and go,
// so a counter kept in the instance's memory forgets everything the moment
// the instance is recycled. The count therefore lives in Redis when the
// deployment has one (Vercel KV / Upstash inject the REST endpoint and the
// token) and in memory when it has none - the old behaviour, kept for local
// runs and for deployments without a store.
//
// Only Redis is spoken to, never a socket: the REST API is one fetch away
// and needs no dependency.

/** Counts one client's answers and returns the count after the new one. */
export interface DailyCounter {
    /** Counts one answer for `client` and returns the count after it. */
    increment(client: string): Promise<number>;
}

/** Two days, so yesterday's key outlives the day it belongs to. */
const KEY_TTL_SECONDS = 172800;

function today(): string {
    return new Date().toISOString().slice(0, 10);
}

/** The client address is part of a Redis key, so keep it tame. */
function keyPart(client: string): string {
    return client.replace(/[^a-zA-Z0-9._:-]/g, "_").slice(0, 64);
}

function counterKey(client: string): string {
    return `mn:draft:${today()}:${keyPart(client)}`;
}

/**
 * The counter of a deployment without a store: one instance, one day, one
 * counter per client address. It forgets everything when the instance dies -
 * that is the limit of this counter, and the reason a store exists.
 */
export function memoryCounter(): DailyCounter {
    const counts = new Map<string, { day: string; count: number }>();
    return {
        async increment(client: string): Promise<number> {
            const day = today();
            const entry = counts.get(client);
            if (!entry || entry.day !== day) {
                counts.set(client, { day, count: 1 });
                return 1;
            }
            entry.count += 1;
            return entry.count;
        },
    };
}

/**
 * The counter of a deployment with a store: one Redis key per client and
 * day, counted with INCR and kept from outliving its day with EXPIRE.
 */
export function redisCounter(baseURL: string, token: string): DailyCounter {
    const endpoint = `${baseURL.replace(/\/+$/, "")}/pipeline`;
    return {
        async increment(client: string): Promise<number> {
            const redisKey = counterKey(client);
            const response = await fetch(endpoint, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    Authorization: `Bearer ${token}`,
                },
                body: JSON.stringify([
                    ["INCR", redisKey],
                    ["EXPIRE", redisKey, KEY_TTL_SECONDS],
                ]),
            });
            if (!response.ok) {
                throw new Error(`the counter store answered ${response.status}`);
            }
            const body = (await response.json()) as { result?: unknown }[] | null;
            const count = Number(body?.[0]?.result);
            if (!Number.isFinite(count)) {
                throw new Error("the counter store answered without a count");
            }
            return count;
        },
    };
}

/**
 * The counter the deployment gets: the store when it has one, memory when it
 * has not. The store's names are the ones Vercel KV and Upstash inject.
 */
export function counterFromEnv(env: NodeJS.ProcessEnv = process.env): DailyCounter {
    const url = env.KV_REST_API_URL ?? env.UPSTASH_REDIS_REST_URL;
    const token = env.KV_REST_API_TOKEN ?? env.UPSTASH_REDIS_REST_TOKEN;
    if (url && token) {
        return redisCounter(url, token);
    }
    return memoryCounter();
}
