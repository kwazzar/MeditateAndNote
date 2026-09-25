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

## Історія прогонів

| Прохід | Дата | Результат | Примітки |
|--------|------|-----------|----------|
| 1 | 2026-09-23 | 20 PASS (усі, п.14 та 17–20 закриті 2026-09-25) | QA спринту 4D завершено |