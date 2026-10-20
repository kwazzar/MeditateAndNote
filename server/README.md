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

The project is linked at the repository root (the `.vercel` folder lives
there), and its **Root Directory is `server`** - so the function lands at
`/api/draft` whether it is built from the repository or uploaded by hand.

```bash
# from the repository root
npx vercel deploy --prod          # manual deploy
npx vercel env add GROQ_API_KEY production   # the Groq key
npx vercel env add GROQ_MODEL production     # a model your key can reach
npx vercel env add DAILY_LIMIT production    # answers per client address per day
npx vercel deploy --prod                     # env vars apply to the next deployment
```

**Deploy on push** (instead of the manual command):

1. Install the Vercel GitHub App for the repository:
   <https://github.com/apps/vercel> → *Install* → pick the account →
   *Only select repositories* → select `MeditateAndNote` → *Install*.
   Without the app installed, Vercel answers: *"To link a GitHub repository,
   you need to install the GitHub integration first."*
2. Link it: `npx vercel git connect` (from the repository root) or
   Project → Settings → Git → *Connect Git Repository*.
3. Push to `main`. Every push builds the `server/` folder and deploys it to
   production.

**The endpoint the app points at** is the project's own domain,
`https://meditate-and-note-ai.vercel.app/api/draft`. It is a project
domain, not a hand-made alias, so it follows every deployment on its own -
an alias pinned to one deployment would serve stale code after the next
push.

The endpoint the app talks to is then `https://<your-domain>/api/draft`.

**Turn the deployment protection off.** A project with Vercel Authentication
on answers `401` (or `404` on the production domain) to every anonymous
request - the app is such a request. Project -> Settings -> Deployment
Protection -> Vercel Authentication -> *Disabled* (or *Only Production*).
The CLI's `--sso` flag does not apply it in every version; the dashboard
does.

**The model must be one your key can reach.** Groq answers
`model_not_found` for a model outside the account's tier. List what the key
can use:

```bash
curl -s https://api.groq.com/openai/v1/models -H "Authorization: Bearer $KEY" \
  | python3 -c "import sys,json; [print(m['id']) for m in json.load(sys.stdin)['data']]"
```

The proxy pins that model (`GROQ_MODEL`); the app never names one.

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

**The switch.** The Android app asks before it sends anything: Settings →
AI drafts → "Use the hosted provider". Off means the user's own endpoint,
on means ours. Either way the note text leaves the device, and the section
says so in as many words - the choice of who receives it belongs to the
user, not to the build.

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

## The daily counter

The cap has to hold between serverless instances - they come and go, so a
count kept in an instance's memory forgets everything the moment the instance
is recycled. The count therefore lives in Redis when the deployment has one:

| | |
|---|---|
| Key | `mn:draft:<date>:<client address>`, counted with `INCR` |
| Store | Upstash / Vercel KV over its REST API - one `fetch`, no dependency |
| Env | `KV_REST_API_URL` + `KV_REST_API_TOKEN` (Vercel KV) or `UPSTASH_REDIS_REST_URL` + `UPSTASH_REDIS_REST_TOKEN` (Upstash) |
| Without a store | the count stays in the instance's memory - the old behaviour, good enough for local runs |
| A store that is down | the count falls back to memory and the answer still goes out: the cap loses its reach, the proxy does not lose its answers |
| The audit trail | one log line per request: `daily count=7 limit=50` |

The counter lives in `api/draft.ts` on purpose: Vercel transpiles the files
of `api/` one by one and does not bundle them, so a module imported from
outside `api/` would be left dangling in the deployment.

The free Upstash plan (500K commands a month) is plenty: one answer costs two
commands, and the cap itself is 50 answers a day per client address.

**Set it up** (the store is a marketplace resource, the dashboard does it):

1. Vercel → the project → **Storage → Create Database → Upstash Redis** →
   plan **Free**, environment **Production** → Connect.
2. Vercel injects `KV_REST_API_URL` and `KV_REST_API_TOKEN` into the project.
   Nothing to copy by hand.
3. Redeploy - env vars apply to the next deployment, not to the running one.

Check that it counts:

```bash
curl -s "$KV_REST_API_URL/get/mn:draft:$(date +%F):1.2.3.4" \
  -H "Authorization: Bearer $KV_REST_API_TOKEN"
```

## Picking the model

Do not guess - measure. `compare-models.mjs` sends the app's own request
once per model and prints the status, the latency, whether the answer came
back in the JSON shape the app expects, and the answer itself:

```bash
GROQ_API_KEY=your-key GROQ_ALLOW_CLIENT_MODEL=1 npm run dev
node compare-models.mjs http://127.0.0.1:8732/api/draft llama-3.3-70b-versatile llama-3.1-8b-instant
```

`GROQ_ALLOW_CLIENT_MODEL=1` is what lets the client name a model; without
it the proxy pins `GROQ_MODEL` and ignores the client. The comparison needs
it, production does not - keep it off there, because the price of an answer
is the server's decision.

What to look at in the result:

| | |
|---|---|
| `format` | `json` means the model followed the shape the app parses; `text` means it answered in plain lines - the app still works (the parser falls back to lines), but the `rationale` is lost |
| `suggestions` | how many of them came back - the app shows up to five |
| `ms` | the latency the user waits |
| the answer | does it name a specific moment from the note, or is it generic advice? The prompt forbids generic advice; a small model breaks that rule more often |

Then set the winner as `GROQ_MODEL` and redeploy - no app change, no
rebuild: the app never names a model.

## Files

| File | What |
|---|---|
| `api/draft.ts` | the function: the whole proxy, the daily counter included |
| `test/draft.test.ts` | the proxy's tests (key, pinned model, token cap, envelope, 429, daily cap) |
| `dev-server.ts` | runs the same function locally |
| `compare-models.mjs` | measures the candidate models against each other |
| `.env.example` | the environment the function reads |
