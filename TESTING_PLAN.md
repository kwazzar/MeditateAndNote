# Testing Plan — MeditateAndNote (NightLoom)

> Основа: замір coverage 2026-09-04 — **29.31%** застосунок (2777/9475 LOC), 128 тестів, усі проходять.
> Мета: закрити ризиковані прогалини в Presentation/Application шарах, не дублюючи вже добре накриті зони.

## Поточний стан (по шарах)

| Шар | Стан | Коментар |
|---|---|---|
| Infrastructure (`Persistence/`) | 🟢 94–99% | Ок, підтримувати |
| Domain (`Models/`) | 🟡 40–98% | `SearchQuery` 0%, `StreakInsight` 18%, `MeditationSession` 40% |
| Application (`Services/`) | 🟡 59–95% | `StreakInsightManager` 0%, `SoundPlayer` 0% |
| Presentation (`ViewModels/`, `Navigation/`) | 🔴 0–65% | `NoteEditorViewModel` 0%, `Router` 23%, DeepLink 0% |
| Views | ⚪ майже 0% | Переважно нормально; тестувати лише нетривіальну логіку |
| UI-тести | ⚪ немає | Окремий рішення-питання |

---

## Phase 1 — Критичні business-логіки (найвищий ризик) ✅ DONE 2026-09-04

### 1.1 NoteEditorViewModel (0% → ціль 80%+)
- Файл: `ViewModels/NoteEditorViewModel.swift` (128 LOC, 24 func)
- Тести через `InMemoryNoteDataSource` + fake-stub, за прикладом `NoteManagerTests`:
  - створення ноты: валідація порожнього title/body, збереження через `NoteManageable`
  - редагування і existing-ноти: merge-поведінка, `NoteOperationError.saveFailed` шлях
  - autosave / дедуплікація збережень (якщо є)
  - archive-взаємодія (інваріант має бути на Entity `Note` — перевірити й дописати)
- Нова файли: `MeditateAndNoteTests/NoteEditorViewModelTests.swift`

### 1.2 Router + DeepLink (23% / 0% → ціль 75%+)
- Файли: `Navigation/Router.swift`, `Navigation/DeepLinkParser.swift`, `Navigation/Destination.swift`
- Тести (plain unit, без UI):
  - push/pop/replace стека, border-кейси: pop порожнього стека, максимальна глибина
  - `DeepLinkParser`: валідні/невалідні URL → правильний `Destination`, невідомі scheme
  - вибір tab при deeplink у інший таб
- Нові файли: `RouterTests.swift`, `DeepLinkParserTests.swift`

### 1.3 Стан пошуку нот
- Файли: `Models/SearchQuery.swift` (0%), `Views/NoteMenu/SearchState.swift` (14%)
- Тести: нормалізація рядка, filtering по title/body, empty query = всі, регістрочутливість
- Новий файл: `SearchQueryTests.swift`

## Phase 2 — Незакриті сервіси ✅ DONE 2026-09-04

### 2.1 StreakInsightManager (0% → ціль 80%+)
- Товсткий engine (`StreakInsightEngine`, 95%) вже накритий — менеджеру потрібні тонкі тести:
  - реакція на `DomainEvent` (як `CoreDataSessionStore.handle()`)
  - read/write через `StreakActivityStore` protocol (mock)
- Новий файл: `StreakInsightManagerTests.swift`

### 2.2 Догілки доменних моделей
- `MeditationSession` (40%): інваріанти тривалості, завершення сесії, edge case нуль-тривалості
- `Note` (54%): `archive()`/`unarchive()` повторний виклик, валідність дати архіву
- `StreakInsight` (18%): фабричні методи / threshold-логіку
- `Meditation` (45%): вибір durations, description-логіка
- Додати існуючі тест-файли або `ModelInvariantsTests.swift`

### 2.3 SoundPlayer (0%)
- Ізолювати авдіо- side effects за protocol (`AudioPlaying`), протестувати lifecycle (play/stop/fade) через mock; сам `AVAudioPlayer` лишити в тонкій адаптер-реалізації без тестів.

## Phase 3 — Підвищення існуючих ViewModel ✅ DONE 2026-09-04

| ViewModel | Зараз | Домашні кейси |
|---|---|---|
| `MeditationViewModel` | 51% | пауза/відміна сесії, шлях помилок `SessionStore`, завершення → streak-подія |
| `NoteMenuViewModel` | 37% | сортування, archive-секція, видалення з підтвердженням |
| `MainViewModel` | 44% | агрегування streak+notes для головного екрана |
| `InsightsViewModel` | 0% | порожній стан vs є дані |
| `MeditateSelectViewModel` | 65% | збереження вибору duration |

## Phase 4 — Структурні рішення (за потреби)

> **Re-eval 2026-09-04:** SearchBar / MeditateButtonComponents / ScrollDetector — це **чисто рендеринг SwiftUI**, без прихованої domain-логіки. Витягати нема що. Тому Phase 4.1 замінено на raise coverage для сервісів/навігації, що мають реальну логіку.

- **4.1 Підняти coverage сервісів/навігації** ✅ DONE 2026-09-04
  - `OnboardingCoordinator` 60 → 100%
  - `NoteSyncCoordinator` 59 → 90%
  - `Router` 67 → 70% (залишок — `logger.debug` галуження)
  - `Meditation` 71 → 71% (додано category / description / notFound)
- **UI-тести (XCUI)**: рішення окремо — дорогі в підтримці; робити лише якщо потрібна регресія на flow "онбординг → медитація → нота".
- **CI**: додати `xcodebuild test -enableCodeCoverage YES` + поріг (напр. не нижчий за поточний %) у пайплайн. ✅ DONE 2026-09-04
  - `.github/workflows/test.yml`: запускає `xcodebuild test` з coverage на `macos-latest`, парсить `xcrun xccov` через Python і падає, якщо `MeditateAndNote.app` coverage < 33.0%. Піднімати поріг разом з ростом coverage.

## Порядок виконання

1. Phase 1.1 → 1.2 → 1.3 (кожен = окремий PR з тестами)
2. Phase 2.1 → 2.2 → 2.3
3. Phase 3 — поступово, разом із фичами що чіпають ці ViewModel
4. Phase 4 — за окремим рішенням

## Критерії готовності

- Кожен phase: нові тести проходять, `Coverage Report` не нижчий за ціль phase
- Цільовий загальний coverage після Phase 1–2: **~45–50%** (решта зростання — це View-лінії, які не ціль)
- Domain-файли тестів не імпортують `SwiftUI`/`CoreData` (перевіряти на review)
- Після кожного шару: оновити graphify (`graphify update .`)
