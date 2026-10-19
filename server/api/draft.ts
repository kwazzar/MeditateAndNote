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

const DEFAULT_GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";
const DEFAULT_MODEL = "llama-3.3-70b-versatile";
const DEFAULT_MAX_TOKENS = 700;
const DEFAULT_DAILY_LIMIT = 50;

/** Per-instance, best-effort daily cap. A durable store would be the real fix. */
const dailyUse = new Map<string, { day: string; count: number }>();

function today(): string {
    return new Date().toISOString().slice(0, 10);
}

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

/** Best effort: one instance, one day, one counter per client address. */
function overDailyLimit(key: string, limit: number): boolean {
    if (limit <= 0) return false;
    const day = today();
    const entry = dailyUse.get(key);
    if (!entry || entry.day !== day) {
        dailyUse.set(key, { day, count: 1 });
        return false;
    }
    entry.count += 1;
    return entry.count > limit;
}

export async function handler(req: any, res: any): Promise<void> {
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
    if (overDailyLimit(clientKey(req), dailyLimit)) {
        res.status(429).json({ error: "rate_limited" });
        return;
    }

    // The client may name a model; the proxy pins its own. The price of the
    // answer is the server's decision, not the caller's.
    const payload = {
        model: process.env.GROQ_MODEL || DEFAULT_MODEL,
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
}

export default handler;
