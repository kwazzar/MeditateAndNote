# Meditate & Note — AI provider proxy

A Vercel function that speaks the OpenAI chat-completions dialect to Groq.

The apps already speak that dialect — the wire protocol lives in the core
package (`AIDraftRemoteProtocol`: the instructions, the request body, the
envelope, the parsing of the answer). Groq speaks it too. So this function
is a pass-through that adds the two things the app must not carry:

- **the provider key** — it stays in the environment, never in an app bundle;
- **the model** — the client may name one, the proxy pins its own. The price
  of an answer is the server's decision.

The answer comes back unchanged, so the app's parser needs no new branch
when the provider behind the endpoint changes.

## Deploy

```bash
cd server
npx vercel deploy --prod          # or connect the folder in the Vercel dashboard
vercel env add GROQ_API_KEY        # the Groq key
vercel env add GROQ_MODEL          # optional, e.g. llama-3.3-70b-versatile
```

The endpoint the app talks to is then
`https://<your-deployment>/api/draft`.

## Point the apps at it

**Android** — the endpoint is a build property, so the app works out of the
box and the user can still change it in Settings → AI drafts:

```bash
cd Android
./gradlew assembleDebug -PaiDraftEndpoint=https://<your-deployment>/api/draft
```

**iOS** — Settings → AI → Remote fallback: the endpoint field takes the
same URL. The API key field stays empty: the proxy carries it. (A key is
still sent when the user fills one in, so a personal OpenAI-compatible
endpoint keeps working the way it did.)

## Run it locally

```bash
cd server
GROQ_API_KEY=your-key npm run dev      # http://127.0.0.1:8732/api/draft
npm test                               # the proxy's own tests
```

`GROQ_URL` points the proxy at another provider — handy for a fake one:

```bash
GROQ_API_KEY=test GROQ_URL=http://127.0.0.1:8733/openai/v1/chat/completions npm run dev
```

## What the proxy guarantees

| | |
|---|---|
| Key | only in the environment; never logged, never sent to the app |
| Model | pinned by `GROQ_MODEL`; the client's choice is ignored |
| Output size | capped by `GROQ_MAX_TOKENS` (700 by default) |
| Cost guard | `DAILY_LIMIT` answers per client address per day (50 by default, 0 turns it off) |
| Privacy | the note text is not logged; only counts and timings are kept |
| Pass-through | the provider's envelope reaches the app as it is, including 429 |

The daily cap is **per instance** — serverless instances come and go, so it
is a guard against a runaway client, not an accounting system. A durable
store (Vercel KV, Upstash) is the real answer when the cap has to hold.

## Files

| File | What |
|---|---|
| `api/draft.ts` | the function: the whole proxy |
| `test/draft.test.ts` | the proxy's tests (key, pinned model, token cap, envelope, 429) |
| `dev-server.ts` | runs the same function locally |
| `.env.example` | the environment the function reads |
