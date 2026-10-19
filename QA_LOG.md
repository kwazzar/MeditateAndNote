# QA Log — Sprint 4 (Semantic Search → keyword-only)

Запис результатів ручного QA. Прохід = один раз по списку нижче, результат в колонці.
Семантика вимкнена (fallback disabled) — порожній результат на промах це норма.

## Прохід #1 (дата: 2026-09-23, середовище: iOS Simulator iPhone 17)

| # | Крок | Очікування | Pass/Fail | Лог/примітка |
|---|------|-----------|-----------|--------------|
| 1 | Чистий старт (uninstall→install) | Онбординг skip → таби рендеряться | PASS | loaded 0→5 notes послідовно, жодного крашу |
| 2 | Empty-state пошук | Запит без нотаток не падає, порожньо | PASS | `'' hits=0`, `xyzzy hits=0` стабільно |
| 3 | Create: 5 нотаток | створено | PASS | `loaded 0→5`; потім 6-та і 7-ма (`loaded 6`,`loaded 7`) |
| 4 | `Mars` | лише Mars | PASS | `Mars hits=1` |
| 5 | `mars` / `MARS` | той самий | PASS | `MARS hits=1` (case-insensitive) |
| 6 | `Mar` | partial | PASS | `Mar hits=1` |
| 7 | `milk` | збіг у тілі | PASS | `milk hits=2` (Groceries+Shopping), `mi hits=3` (+mission) |
| 8 | `планет`, `МАРС` | кирилиця | PASS | `планет/план/п hits=1`, `МАРС/МАР/М hits=1` |
| 9 | `xyzzy` | порожньо | PASS | `xyzzy..x hits=0` весь ланцюг |
| 10 | `" Mars "` (тримінг) | = `Mars` | PASS | UI-тест `testTrimTabSwitchAndRestart`: матчінг триміть (`" Mars "` знайшов Mars); поле показує сирий ввід — трим на рівні матчу, не display |
| 11 | clear (×) | усі назад | PASS | `'' hits=0` → список усіх |
| 12 | Пошук + create | запит зберігся, результати оновились | PASS* | нотатка створена при активному `Mar` → `loaded 6` → `Mar hits=1` (стан зберігся; нова нотатка не збігалась) |
| 13 | Switch табів | зафіксувати поведінку | PASS | UI-тест: запит і результати переживають Notes→Home→Notes (query survives) |
| 14 | Edit Groceries→Grocery list | `Groceries` не б'є | PASS | UI-тест `testRenameNoteUpdatesSearch`: старий title перестає матчити, новий б'є в пошуку |
| 15 | Delete з результатів | рядок зникає | PASS | `loaded 6` + `Gro hits=0` після видалення |
| 16 | Рестарт app | дані є, пошук працює | PASS | UI-тест: нотатки персистентні; пошук скидається (in-memory VM) |
| 17 | VoiceOver Back/Clear | лейбли | PASS | за кодом: `.accessibilityLabel("Back")` (NoteEditorView.swift:129), `("Clear search")` (SearchBar.swift:45) |
| 18 | Dark mode / Large text | читабельність | PASS | dark + accessibility-extra-large: верстка тримається, ~2 картки на екран (норма XL), текст читається |
| 19 | Regression: медитація→streak | streak росте | PASS | медитацію дотиснуто, streak на Home збільшився |
| 20 | Regression: AI-інсайти | працюють | PASS | секція Insights: теми + 3 картки (summary + теги), refresh працює; аналіз на debounced-події (нова/редагована нотатка + ~30с), heuristic fallback без FM |

## Прохід Android AI Insights (дата: 2026-10-20, середовище: Android emulator `emulator-5554` / Medium_Phone_API_37.0, API 37, arm64)

| # | Крок | Очікування | Pass/Fail | Лог/примітка |
|---|------|-----------|-----------|--------------|
| 1 | Чистий старт, онбординг skip | таби рендеряться, крашів немає | PASS | notes-таб відкрився, список порожній, секції інсайтів немає (порожній стор → блок приховано) |
| 2 | Створення нотатки (Add Note) | нотатка збережена | PASS | title `Untitled`, body `calm breathing practice for anxiety before sleep`; окремо зафіксовано: поле title уже містить `Untitled`, тому ввод додається перед ним (поведінка редактора, не інсайтів) |
| 3 | Секція «✨ Insights» | блок над списком | PASS | заголовок + кнопка refresh (`contentDescription` = «Refresh insights») |
| 4 | Чипи тем | до 5 тем | PASS | `breathing`, `sleep`, `calm`, `practice`, `anxiety` |
| 5 | Картка інсайту | summary + теги | PASS | summary `calm breathing practice for anxiety before sleep`, рядок `#breathing #sleep #calm #practice #anxiety` |
| 6 | Refresh | перерахунок | PASS | набір тем змінився (порядок при рівних частотах випадковий — `Dictionary` у Swift, спільно з iOS), контент той самий |
| 7 | Collapse (тап по заголовку) | блок згортається | PASS | лише заголовок + refresh, чипи й картка сховалися |
| 8 | Порожній стор | секція прихована | PASS | після `NoteBlobStore.deleteAll()` у контракт-тесті — блок не рендериться, crash немає |
| 9 | Аналіз не блокує UI | відгук лишається плавним | PASS | аналіз на `Dispatchers.IO`, main thread вільний |
| 10 | Регресія: список нотаток | список як раніше | PASS | карточка нотатки під секцією, дата «20 October», «Read» на місці |

**Автотести:** `connectedDebugAndroidTest` — 31/31 PASS (3 нові в `NoteInsightsContractTest`: інсайти є, порожній стор → порожній список, `topThemes` ранжує). iOS: `NoteInsightTests` — 14/14 PASS (2 нові на `analyzeSync`).

## Прохід Android AI Draft (дата: 2026-10-20, середовище: Android emulator `emulator-5554` / Medium_Phone_API_37.0, API 37, arm64, провайдер: локальний mock на `10.0.2.2:8731`)

| # | Крок | Очікування | Pass/Fail | Лог/примітка |
|---|------|-----------|-----------|--------------|
| 1 | Settings → секція «AI drafts» | endpoint, model, API key | PASS | поля зберігаються; key у prefs — лише шифротекст (`api_key_cipher` + `api_key_iv`), ключ у Keystore |
| 2 | Третє поле «API key» | маскований | PASS | показується `••••••••`; у logcat не потрапляє |
| 3 | Нотатка з текстом, тап по ✨ | підказки приходять | PASS | «Proposals»: «What did the river sound like this morning?» + «Try describing the moment before you felt calm.» |
| 4 | Запит до провайдера | правильний формат | PASS | body = system-інструкції + `Request: Give me ideas to continue this note` + текст нотатки (спільне правило з Core) |
| 5 | Accept однієї підказки | переходить у «Accepted» | PASS | рядок «Accepted» з’явився, у підказки лишився «Remove», з’явився «Transfer (1)» |
| 6 | Accept All / Remove | масові дії | PASS | `acceptAll` переносить усі pending; `reject` повертаєAccepted у pending (контракт-тест) |
| 7 | Transfer (1) | текст потрапляє в нотатку | PASS | body = `I walked by the river this morning and felt very calm.\n\nWhat did the river sound like this morning?` — порожній рядок-роздільник, як в iOS |
| 8 | Лічильник квоти | зростає на успішну генерацію | PASS | `ai_draft_quota.xml` → `used=1` |
| 9 | Квота вичерпана | 6-та генерація відхиляється | PASS | контракт-тест: після 5 успішних — `freeQuotaExhausted` |
| 10 | Провайдер падає | зрозуміла помилка | PASS | контракт-тест: HTTP 500 → `providerUnavailable`, UI показує «Could not generate suggestions» |
| 11 | Без ключа | не мертва кнопка | PASS | без ключа показується «Add an API key in Settings to use AI drafts» |
| 12 | Регресія: інсайти | працюють | PASS | секція Insights у списку нотаток на місці, 31/31 тестів зелені |

**Автотести:** `connectedDebugAndroidTest` — 38/38 PASS (7 нових у `AIDraftContractTest`: підказки приходять, без контексту — питання, accept/reject/acceptAll, квота, помилка провайдера). iOS: `RemoteLLMDraftServiceTests` + `AIDraftManagerTests` + `AIDraftSessionTests` — 50/50 PASS.

## Прохід Android AI Draft — сесія + метрики (дата: 2026-10-20, середовище: Android emulator `emulator-5554`, провайдер: локальний mock на `10.0.2.2:8731`)

| # | Крок | Очікування | Pass/Fail | Лог/примітка |
|---|------|-----------|-----------|--------------|
| 1 | Налаштувати endpoint (без ключа) | провайдер вважається налаштованим | PASS | гейт тепер на endpoint, а не на ключ: endpoint без авторизації працює; ключ лишається необов'язковим |
| 2 | Тап по ✨ у нотатці | підказки приходять | PASS | «Proposals» + 2 підказки від mock-провайдера |
| 3 | Вийти з редактора, відкрити нотатку знову | сесія на місці, без нової генерації | PASS | ті самі дві підказки одразу після відкриття; лічильник квоти лишився `used=1` — квота не з'їдена повторно |
| 4 | Сховище сесій | документ непрозорий, один на нотатку | PASS | `ai_draft_sessions.xml` → `session_<noteId>` = JSON, який написав Swift |
| 5 | Метрики генерації | рядки в базі | PASS | `ai_draft_metrics`: `generationStarted(warm_cold=1)`, `generationCompleted(latency_ms=721, suggestion_count=2)` |
| 6 | Метрики вставки/відхилення | індекси підказок | PASS | `suggestionInserted` / `suggestionRejected` пишуться при Transfer і Remove |
| 7 | Видалення нотатки | сесія викидається | PASS | команда `discardSession` прибирає документ нотатки |
| 8 | Без провайдера | зрозуміла підказка | PASS | «Set the AI provider in Settings to use AI drafts» |

**Автотести:** `connectedDebugAndroidTest` — 42/42 PASS (4 нові: сесія переживає закриття редактора, `discard` прибирає її, міст несе метрику генерації, метрика пишеться в Room).

## Історія прогонів

| Прохід | Дата | Результат | Нотатки |
|--------|------|-----------|----------|
| 1 | 2026-09-23 | 20 PASS (усі, п.14 та 17–20 закриті 2026-09-25) | QA спринту 4D завершено |
| 2 | 2026-10-20 | 10 PASS (Android AI Insights) | v1 інсайтів на Android, без LLM |
| 3 | 2026-10-20 | 12 PASS (Android AI Draft) | v2 чернетки: remote-провайдер, парітет з iOS |
| 4 | 2026-10-20 | 8 PASS (сесія + метрики) | v3: чернетка переживає закриття редактора, телеметрія як в iOS |