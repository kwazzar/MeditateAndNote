//
//  compare-models.mjs
//  server
//
//  Picks the model by measuring it: the same request the app sends, once per
//  model, and a table of what came back.
//
//  It talks to the proxy (not to Groq directly), so the provider key stays
//  on the server. The deployment must allow the client to name the model:
//
//      GROQ_ALLOW_CLIENT_MODEL=1
//
//  Usage:
//      node compare-models.mjs [proxyUrl] [model ...]
//
//  The prompt below is the one the app sends (AIDraftRemoteProtocol in the
//  core package) - a copy, so a change there should be copied here too.
//

const proxyUrl = process.argv[2] || "http://127.0.0.1:8732/api/draft";
const models = process.argv.slice(3).length > 0
    ? process.argv.slice(3)
    : [
          "llama-3.3-70b-versatile",
          "llama-3.1-8b-instant",
          "openai/gpt-oss-120b",
          "moonshotai/kimi-k2-instruct",
      ];

const SYSTEM = `You are a reflective journaling assistant in an app called MeditateAndNote. Read the user's note and their request, then offer concise, thoughtful suggestions to help them continue. Every suggestion must name a specific moment, detail or feeling from the note above — generic advice is not acceptable. Never invent personal facts. Keep each suggestion under 140 characters. Return suggestions as a JSON object in this format: {"suggestions": [{"text": "suggestion text", "rationale": "short reason"}]}`;

const USER = `Request: Give me ideas to continue this note

Current note content:
I walked by the river this morning before work. The water was low and grey, and there was one fisherman who did not look up. I felt calm for the first time in a week, and then slightly sad that the calm was going to end at the office door.`;

/** The same shape the app's parser expects. */
function parse(content) {
    try {
        const parsed = JSON.parse(content);
        const items = Array.isArray(parsed?.suggestions) ? parsed.suggestions : [];
        return items
            .filter((item) => typeof item?.text === "string" && item.text.length > 0)
            .map((item) => item.text);
    } catch {
        return null;
    }
}

console.log(`proxy: ${proxyUrl}\n`);
const rows = [];

for (const model of models) {
    const startedAt = Date.now();
    try {
        const response = await fetch(proxyUrl, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                model,
                messages: [
                    { role: "system", content: SYSTEM },
                    { role: "user", content: USER },
                ],
                temperature: 0.7,
            }),
        });
        const elapsed = Date.now() - startedAt;
        const body = await response.json();
        const content = body?.choices?.[0]?.message?.content ?? "";
        const suggestions = parse(content);
        rows.push({
            model,
            status: response.status,
            ms: elapsed,
            chars: content.length,
            format: suggestions ? "json" : "text",
            count: suggestions ? suggestions.length : 0,
            answer: content,
        });
    } catch (error) {
        rows.push({
            model,
            status: "ERR",
            ms: Date.now() - startedAt,
            chars: 0,
            format: "-",
            count: 0,
            answer: String(error?.message ?? error),
        });
    }
}

for (const row of rows) {
    console.log(`${row.model}  status=${row.status}  ${row.ms}ms  format=${row.format}  suggestions=${row.count}`);
    console.log(`  ${row.answer.replace(/\s+/g, " ").slice(0, 300)}`);
    console.log("");
}
