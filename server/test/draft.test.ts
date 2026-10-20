//
//  draft.test.ts
//  server/test
//
//  The proxy is a pass-through with two decisions of its own: the model is
//  pinned, and the provider key comes from the environment. These tests
//  hold both, and the envelope on the way back.
//

import test from "node:test";
import assert from "node:assert/strict";
import { counterFromEnv, createHandler, handler, memoryCounter, redisCounter } from "../api/draft.ts";

type Res = {
    statusCode: number;
    headers: Record<string, string>;
    body: string;
    status(code: number): Res;
    json(value: unknown): Res;
    send(value: string): Res;
    setHeader(name: string, value: string): Res;
};

function fakeRes(): Res {
    const res: Res = {
        statusCode: 200,
        headers: {},
        body: "",
        status(code) {
            res.statusCode = code;
            return res;
        },
        json(value) {
            res.body = JSON.stringify(value);
            return res;
        },
        send(value) {
            res.body = value;
            return res;
        },
        setHeader(name, value) {
            res.headers[name] = value;
            return res;
        },
    };
    return res;
}

function stubFetch(status: number, body: string): { calls: any[] } {
    const calls: any[] = [];
    globalThis.fetch = (async (url: any, init: any) => {
        calls.push({ url: String(url), init });
        return new Response(body, { status });
    }) as typeof fetch;
    return { calls };
}

test("a non-POST request is refused", async () => {
    const res = fakeRes();
    await handler({ method: "GET", headers: {} }, res);
    assert.equal(res.statusCode, 405);
});

test("without a provider key the proxy reports the provider as unavailable", async () => {
    const previous = process.env.GROQ_API_KEY;
    delete process.env.GROQ_API_KEY;
    const res = fakeRes();
    await handler({ method: "POST", headers: {}, body: { messages: [{ role: "user", content: "hi" }] } }, res);
    assert.equal(res.statusCode, 503);
    if (previous !== undefined) process.env.GROQ_API_KEY = previous;
});

test("a request without messages is a bad request", async () => {
    process.env.GROQ_API_KEY = "test-key";
    stubFetch(200, "{}");
    const res = fakeRes();
    await handler({ method: "POST", headers: {}, body: { model: "gpt-4o-mini" } }, res);
    assert.equal(res.statusCode, 400);
});

test("the key, the pinned model and the token cap are the proxy's business", async () => {
    process.env.GROQ_API_KEY = "test-key";
    process.env.GROQ_MODEL = "llama-3.3-70b-versatile";
    process.env.GROQ_MAX_TOKENS = "700";
    const provider = stubFetch(200, JSON.stringify({ choices: [{ message: { content: "ok" } }] }));

    const res = fakeRes();
    await handler(
        {
            method: "POST",
            headers: { "x-forwarded-for": "10.0.0.1" },
            body: {
                model: "gpt-4o-mini", // the client's choice is ignored
                messages: [
                    { role: "system", content: "be brief" },
                    { role: "user", content: "a note about a calm river" },
                ],
                temperature: 0.4,
            },
        },
        res,
    );

    assert.equal(res.statusCode, 200);
    assert.equal(provider.calls.length, 1);

    const call = provider.calls[0];
    assert.match(call.url, /chat\/completions$/);
    assert.equal(call.init.headers.Authorization, "Bearer test-key");

    const sent = JSON.parse(call.init.body);
    assert.equal(sent.model, "llama-3.3-70b-versatile");
    assert.equal(sent.max_tokens, 700);
    assert.equal(sent.temperature, 0.4);
    assert.deepEqual(sent.messages.map((m: any) => m.role), ["system", "user"]);
});

test("a deployment may let the client name the model (the comparison tool)", async () => {
    process.env.GROQ_API_KEY = "test-key";
    process.env.GROQ_MODEL = "pinned-model";
    process.env.GROQ_ALLOW_CLIENT_MODEL = "1";
    const provider = stubFetch(200, JSON.stringify({ choices: [{ message: { content: "ok" } }] }));

    await handler(
        {
            method: "POST",
            headers: {},
            body: { model: "client-model", messages: [{ role: "user", content: "hi" }] },
        },
        fakeRes(),
    );

    const sent = JSON.parse(provider.calls[0].init.body);
    assert.equal(sent.model, "client-model");
    delete process.env.GROQ_ALLOW_CLIENT_MODEL;
});

test("the provider's envelope reaches the app unchanged", async () => {
    process.env.GROQ_API_KEY = "test-key";
    const envelope = JSON.stringify({
        choices: [{ message: { content: "{\"suggestions\":[{\"text\":\"keep walking\"}]}" } }],
    });
    stubFetch(200, envelope);

    const res = fakeRes();
    await handler(
        { method: "POST", headers: {}, body: { messages: [{ role: "user", content: "hi" }] } },
        res,
    );

    assert.equal(res.body, envelope);
    assert.equal(res.headers["Content-Type"], "application/json");
});

test("a rate limited provider stays a 429 for the app", async () => {
    process.env.GROQ_API_KEY = "test-key";
    stubFetch(429, JSON.stringify({ error: "rate limit" }));

    const res = fakeRes();
    await handler(
        { method: "POST", headers: {}, body: { messages: [{ role: "user", content: "hi" }] } },
        res,
    );

    assert.equal(res.statusCode, 429);
});

// MARK: - The daily cap

/** A counter that counts in memory and remembers who it counted. */
function fakeCounter(): { increment(client: string): Promise<number>; clients: string[] } {
    const counts = new Map<string, number>();
    const clients: string[] = [];
    return {
        clients,
        async increment(client: string) {
            clients.push(client);
            const next = (counts.get(client) ?? 0) + 1;
            counts.set(client, next);
            return next;
        },
    };
}

test("the daily cap holds between instances that share the counter", async () => {
    process.env.GROQ_API_KEY = "test-key";
    process.env.DAILY_LIMIT = "1";
    stubFetch(200, JSON.stringify({ choices: [{ message: { content: "ok" } }] }));

    // Two instances, one counter: the second one still sees the first one's
    // answer. This is the whole point of a store - a counter in an instance's
    // memory would let the second instance start from zero.
    const counter = fakeCounter();
    const request = {
        method: "POST",
        headers: { "x-forwarded-for": "10.0.0.1" },
        body: { messages: [{ role: "user", content: "hi" }] },
    };

    const first = fakeRes();
    await createHandler(counter)(request, first);
    const second = fakeRes();
    await createHandler(counter)(request, second);

    assert.equal(first.statusCode, 200);
    assert.equal(second.statusCode, 429);
    assert.deepEqual(counter.clients, ["10.0.0.1", "10.0.0.1"]);
    delete process.env.DAILY_LIMIT;
});

test("a cap of zero turns the counter off", async () => {
    process.env.GROQ_API_KEY = "test-key";
    process.env.DAILY_LIMIT = "0";
    stubFetch(200, JSON.stringify({ choices: [{ message: { content: "ok" } }] }));

    const counter = fakeCounter();
    const request = {
        method: "POST",
        headers: { "x-forwarded-for": "10.0.0.2" },
        body: { messages: [{ role: "user", content: "hi" }] },
    };

    const res = fakeRes();
    await createHandler(counter)(request, res);

    assert.equal(res.statusCode, 200);
    assert.deepEqual(counter.clients, []);
    delete process.env.DAILY_LIMIT;
});

test("a counter that is unreachable does not take the proxy down", async () => {
    process.env.GROQ_API_KEY = "test-key";
    process.env.DAILY_LIMIT = "50";
    stubFetch(200, JSON.stringify({ choices: [{ message: { content: "ok" } }] }));

    const broken = {
        async increment(): Promise<number> {
            throw new Error("the store is down");
        },
    };

    const res = fakeRes();
    await createHandler(broken)(
        {
            method: "POST",
            headers: { "x-forwarded-for": "10.0.0.3" },
            body: { messages: [{ role: "user", content: "hi" }] },
        },
        res,
    );

    assert.equal(res.statusCode, 200);
    delete process.env.DAILY_LIMIT;
});

test("the store's counter counts one key per client and day", async () => {
    const provider = stubFetch(200, JSON.stringify([{ result: 3 }, { result: 1 }]));

    const counter = redisCounter("https://db.upstash.io/", "secret-token");
    const count = await counter.increment("10.0.0.4");

    assert.equal(count, 3);
    assert.equal(provider.calls.length, 1);

    const call = provider.calls[0];
    assert.equal(call.url, "https://db.upstash.io/pipeline");
    assert.equal(call.init.headers.Authorization, "Bearer secret-token");

    const commands = JSON.parse(call.init.body);
    assert.equal(commands[0][0], "INCR");
    assert.match(commands[0][1], /^mn:draft:\d{4}-\d{2}-\d{2}:10\.0\.0\.4$/);
    assert.equal(commands[1][0], "EXPIRE");
});

test("a deployment with a store gets the store's counter, without one the local one", async () => {
    const previousURL = process.env.KV_REST_API_URL;
    const previousToken = process.env.KV_REST_API_TOKEN;
    delete process.env.KV_REST_API_URL;
    delete process.env.KV_REST_API_TOKEN;

    const provider = stubFetch(200, JSON.stringify([{ result: 1 }]));

    const local = counterFromEnv();
    await local.increment("10.0.0.7");
    assert.equal(provider.calls.length, 0, "the local counter asks nobody");

    process.env.KV_REST_API_URL = "https://db.upstash.io";
    process.env.KV_REST_API_TOKEN = "secret-token";
    const stored = counterFromEnv();
    await stored.increment("10.0.0.7");
    assert.equal(provider.calls.length, 1, "the store's counter asks Redis");

    if (previousURL === undefined) delete process.env.KV_REST_API_URL;
    else process.env.KV_REST_API_URL = previousURL;
    if (previousToken === undefined) delete process.env.KV_REST_API_TOKEN;
    else process.env.KV_REST_API_TOKEN = previousToken;
});

test("the local counter counts one client separately from another", async () => {
    const counter = memoryCounter();

    assert.equal(await counter.increment("10.0.0.5"), 1);
    assert.equal(await counter.increment("10.0.0.5"), 2);
    assert.equal(await counter.increment("10.0.0.6"), 1);
});
