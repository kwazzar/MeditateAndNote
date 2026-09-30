# MeditateAndNote — план портування на Android

> Базується на існуючій DDD-архітектурі (Presentation → Application → Domain ← Infrastructure) з протокольними `DataSource`/`Store` контрактами.

## Принцип

Domain-шар платформо-незалежний за визначенням DDD. Портування — це не переписування логіки, а **додавання нових реалізацій існуючих протоколів** під Android, там де Apple SDK не має прямого аналога.

---

## Рекомендації (на основі аналізу кодової бази)

> Додано: 2026-09-30, на основі аналізу структури проєкту (Models/, Services/, Persistence/)

### 1. Observation framework — найбільший прихований блокер

`@Observable` (Observation framework) **не є крос-платформенним**. Він входить до Apple SDK (iOS 17+, macOS 14+) і не компілюється під Swift SDK for Android. У проекті використовується не лише в Presentation, але й в Application-шарі (`StreakTracker`, `ReminderManager`, `ThemeManager`).

**Рекомендація:** розглянути KMP (Kotlin Multiplatform) як основний шлях, а не Swift SDK for Android. Причини:
- Swift SDK for Android експериментальний; `@Observable` гарантовано не працює
- KMP дозволяє залишити Domain на Kotlin/Compose для Presentation, зберігаючи єдиний домен
- Якщо Swift SDK обирається свідомо — потрібен абстрактний шар над Observation (протокол + дві реалізації: Apple `@Observable` та Android-еквівалент через `StateFlow`/`LiveData`)

### 2. AI-стратегія — pivot обов'язковий

`FoundationModels` (iOS 26+) не має аналога на Android. `NLEmbedding` (NaturalLanguage framework) — теж iOS-only.

**Рекомендація:**
- **Рівень 1 (базовий):** ML Kit GenAI (Rewriting/Summarization) — простіший старт, але Beta
- **Рівень 1 (альтернатива):** AICore SDK (`generateContentStream`) — потрібен ручний парсинг
- **Рівень 2 (structured output):** на Android неможливий «з коробки» — емуляція через "return strict JSON" prompt + `Decodable`
- **NLEmbedding:** замінити на TensorFlow Lite embeddings або деградувати до keyword search на Android

### 3. CoreData → Room — міграція схеми вимагає явного мапінгу

CoreData-модель має сутності з зв'язками (`Note` → `AIDraftSession`, `MeditationSession` → `DailyActivity` тощо). Room потребує нормалізації цих зв'язків у таблиці з зовнішніми ключами.

**Рекомендація:** створити мапінг-документ перед початком міграції. Кожен `CoreDataStore` → відповідний Room DAO з явними типами зв'язків (`@Relation`, `@ForeignKey`).

### 4. Swift Concurrency — портовано, але з застереженнями

Актори, `@MainActor`, `AsyncStream` входять у Swift stdlib і компілюються під Android. Але:
- `@MainActor` мапиться на головний UI-потік Android — потрібен рантайм-тест
- `DomainEventBus` публікує «on the emitter's thread» — JNI callbacks з AICore будуть на інших потоках
- `async/await` працює, але `Task.detached` може мати іншу семантику

**Рекомендація:** смоук-тест concurrency (актор + AsyncStream consumer) обов'язковий перед Фазою 2.

### 5. Calendar/Date-математика — edge-case тести необхідні

`ReminderScheduleBuilder` використовує `Calendar`/`TimeZone`. swift-corelibs-foundation на Android має ці типи, але поведінка DST-переходів і локалей може відрізнятися.

**Рекомендація:** окремий набір тестів на DST-перехід, різні часові пояси, локалі — прогнати на Android-збірці.

### 6. UserDefaults → SharedPreferences — міграція форматів

`UserDefaultsStreakStore` має історію форматів даних. Android-еквівалент (SharedPreferences/DataStore) не успадковує її автоматично.

**Рекомендація:** свідоме рішення — портувати міграцію або почати з чистого стану. Якщо застосунок ще не в проді — почати з чистого стану.

### 7. Вибір шляху компіляції — KMP vs Swift SDK

| | Swift SDK for Android | KMP (Kotlin Multiplatform) |
| --- | --- | --- |
| Переваги | Domain-код не дублюється | Зріла екосистема, стабільний toolchain, Compose |
| Ризики | Більше ручної роботи, WIP-статус | Ручна синхронізація логіки |
| Коли обрати | Прототип, швидкий старт | Продакшн-реліз, довгострокова підтримка |

**Рекомендація:** для перевірки концепції — Swift SDK. Для продакшну — KMP з Compose.

### 8. Тестові стратегія — golden tests для domain-логіки

Замість дублювання тестів на дві мови — використовувати golden tests: один набір тестових даних → очікуваний результат. Прогнати на обох платформах і порівняти результати. Це гарантує паритет логіки без дублювання коду тестів.

### 9. Простор імен — зберегти контракти незмінними

Усі `<X>DataSource`/`<X>Store` протоколи мають залишитися без змін у Domain-шарі. Реалізації (`RoomNoteDataSource`, `AndroidSoundPlayer`) додаються в Infrastructure-шар під Android.

---

## Фаза -1 — Аналіз переносу в Core (перше, що робиться)

Мета: перевірити компілятором, а не на око, наскільки Domain+Application реально чисті, перш ніж писати будь-який план далі як факт.

- [ ] Створити локальний SPM-пакет `Packages/MeditateAndNoteCore` усередині поточного репо (без зламу iOS-білду)
- [ ] Перенести `Models/` (entities, value objects, pure engines) у пакет першими — найбезпечніша частина
- [ ] Скомпілювати пакет ізольовано — зафіксувати кожну помилку компіляції як приховану залежність від Apple SDK
- [ ] Для кожної знайденої залежності вирішити: абстрагувати протоколом (лишається в Core) чи визнати платформо-специфічною (переїжджає в Infrastructure)
- [ ] Перенести `Services/` (Managers) — складніша частина, більше протокольних меж
- [ ] Усунути виняток `CoreDataSessionStore` — дати йому протокол за зразком `CoreDataStreakStore`/`StreakActivityStore`, щоб з'явилась точка для Android-реалізації (наразі документовано як "accepted exception" без абстракції)
- [ ] Смоук-тест concurrency на Swift SDK for Android: скомпілювати **і запустити** (не лише скомпілювати) один актор + один `AsyncStream`-consumer через `@MainActor`, аналогічно до `DomainEventBus`/`NoteManager` — перевірити рантайм-поведінку, а не лише компільованість
- [ ] Зафіксувати фактичний % переносного коду (замість оцінки "90-95% на око") і звірити з рештою плану — за потреби скоригувати Фази 0-5 нижче

**Результат фази:** підтверджена (не гіпотетична) межа Core/Infrastructure, на яку спираються всі наступні фази.

---

## Знахідки з аналізу кодової бази

Конкретні ризики, виявлені в наявному коді — враховані вище у Рекомендаціях та Фазі -1, зафіксовані тут для довідки.

- **Доведений патерн градуйованої AI-доступності.** `AIDraftService` вже має три реалізації (`FoundationModelsAIDraftService` iOS 26+, `RemoteLLMDraftService` fallback, `DisabledAIDraftService`); `NoteAnalyzer` — дві (`HeuristicNoteAnalyzer` завжди, `FoundationModelsNoteAnalyzer` iOS 26+). Android-реалізація (`AICoreAIDraftService`) додається як ще один варіант за тим самим контрактом — не новий концепт, а розширення існуючого патерну.
- **`CoreDataSessionStore` без протоколу** — єдиний Infrastructure-компонент без абстракції; без фіксу немає куди підставити Android-реалізацію.
- **`@MainActor`/актори/`AsyncStream`** — базуються на Swift Concurrency, теоретично портовані через мову, але `@MainActor` як концепція головного UI-потоку потребує окремої перевірки рантайм-поведінки на Android (не лише компільованості).
- **`@Observable` в Application-шарі, не лише Presentation** — `StreakTracker`, `ReminderManager`, `ThemeManager` використовують Observation framework поза ViewModels. Перевірити явно, чи Observation валідований для Swift SDK for Android (у публічному списку бібліотек станом на аналіз значились лише Foundation/Dispatch/XCTest/swift-log).
- **`Codable`-серіалізація** (`SessionDuration` та інші) — теоретично портована через Foundation, але варто протестувати на Android-компільованій збірці окремо, не покладаючись на припущення сумісності.
- **`Calendar`/`Date`-математика** в `ReminderScheduleBuilder` — "чиста" логіка, але залежить від поведінки `Calendar`/`TimeZone` у swift-corelibs-foundation; потрібні edge-case тести (DST-перехід, локалі) саме на Android-збірці.
- **Legacy-міграція в `UserDefaultsStreakStore`** — існує історія форматів даних, яку Android-еквівалент (SharedPreferences/DataStore) не успадковує автоматично; потрібне свідоме рішення — портувати міграцію чи почати з чистого стану.
- **`DomainEventBus` публікує "on the emitter's thread"** — на Android потоки виклику з AICore SDK (JNI callback) можуть відрізнятись від Swift-таскового пулу; перевірити передбачуваність потоку публікації подій.

---

## Фаза 0 — Підготовка контрактів (робиться на iOS, до будь-якого Android-коду)

- [ ] Аудит усіх `<X>DataSource`/`<X>Store` протоколів — переконатись, що жоден не "протікає" Apple-типами (`NSManagedObject`, `UIImage` тощо) у публічний контракт
- [ ] Винести `AIWritingService` (рівень 1, платформонезалежний) окремо від `StructuredAIWritingService` (рівень 2, Apple-специфічний structured output)
- [ ] Ввести `AICapabilityLevel` (`.unavailable` / `.basicText` / `.structuredOutput`) замість бінарного `isAvailable`
- [ ] Переконатись, що `NoteManager`, `StreakTracker`, `InsightManager` залежать лише від протоколів рівня 1, ніколи від `StructuredAIWritingService` напряму

**Результат фази:** Domain + Application шари готові приймати підміну реалізацій без змін коду.

---

## Фаза 1 — Вибір шляху компіляції домену

Два варіанти, обрати один до старту Фази 2:

- [ ] Прототип: скомпілювати 2-3 чистих Domain-типи (одну Value Object, один pure engine) через обраний шлях
- [ ] Виміряти розмір білду / складність toolchain-налаштування

---

## Фаза 2 — Infrastructure: реалізації під Android

Кожен пункт — нова реалізація існуючого протоколу, за зразком того, як зараз співіснують `CoreData`/`InMemory`.

| Apple-реалізація | Протокол | Android-реалізація |
| --- | --- | --- |
| CoreData Store | `<X>Store` | Room / SQLDelight |
| Keychain | `SecureStore`-подібний протокол | Android Keystore / EncryptedSharedPreferences |
| AVFoundation | `SoundPlayer`-подібний протокол | ExoPlayer / MediaPlayer |
| UserNotifications | `ReminderScheduler`-подібний протокол | AlarmManager + NotificationManager |
| FoundationModels | `AIWritingService` / `StructuredAIWritingService` | AICore SDK / ML Kit GenAI |

- [ ] Room/SQLDelight реалізація `<X>Store` — мігрувати схему з CoreData моделі
- [ ] Keystore-based `SecureStore`
- [ ] ExoPlayer-based sound service
- [ ] AlarmManager-based reminder service (враховуючи 7-денний notification horizon)
- [ ] AI-сервіс — див. Фазу 3 окремо, найскладніша частина

---

## Фаза 3 — AI-сервіс: уніфікація протоколів

### 3.1 Базовий контракт (рівень 1, спільний)

```swift
protocol AIWritingService {
    var capabilityLevel: AICapabilityLevel { get }
    func generateDraft(prompt: String, context: NoteContext) async throws -> String
    func summarize(text: String, style: SummaryStyle) async throws -> String
}
```

- [ ] Apple-реалізація: обгортка над `FoundationModels`, вільний текстовий режим
- [ ] Android-реалізація A: `AICoreService` — через AICore SDK (`generateContentStream`), з ручним парсингом там, де потрібна структура
- [ ] Android-реалізація B (простіший старт): `MLKitGenAIService` — готові Rewriting/Summarization API замість власного prompt engineering

### 3.2 Розширений контракт (рівень 2, опційний)

```swift
protocol StructuredAIWritingService: AIWritingService {
    func generateStructured<T: Generable>(prompt: String) async throws -> T
}
```

- [ ] Apple: пряма реалізація через `@Generable`
- [ ] Android: або не реалізовувати (фічі, що залежать від structured output, автоматично деградують до рівня 1), або емулювати через "return strict JSON" prompt + ручний `Decodable`-парсинг

### 3.3 UI-адаптація під градуйовану доступність

- [ ] `AIWritingViewModel` реагує на `AICapabilityLevel`, а не на бінарний прапорець
- [ ] Визначити UX для кожного рівня: `.unavailable` → кнопка прихована, `.basicText` → "Help me write" доступний без гарантії формату, `.structuredOutput` → повний функціонал

---

## Фаза 4 — Presentation: Compose з нуля

Ніщо з SwiftUI не переноситься — але структура ViewModels (через `@Observable`) концептуально мапиться на Compose `State`/`ViewModel`.

- [ ] Спроєктувати Compose-еквіваленти екранів у тому ж порядку, що й existing Views/ (onboarding → meditation list → breathing UI → journal → insights)
- [ ] Breathing-анімації: `Canvas`/`TimelineView`/`trim(from:to:)` → Compose `Canvas` + `Animatable`/`rememberInfiniteTransition`
- [ ] Router: адаптувати кастомну Router-навігацію під Navigation Compose, зберігаючи ті самі destinations/deep links на рівні контракту

---

## Фаза 5 — Тести та валідація

- [ ] Портувати pure-engine тести (streak-логіка, insights) — мають пройти без змін, якщо Domain дійсно чистий
- [ ] Contract-тести для кожного нового `Store`/`Service` — та сама тестова сюїта, що й для CoreData/InMemory, прогнана проти Android-реалізацій
- [ ] Окремі device-матриця тести для AI-фіч: пристрій без AICore, пристрій з `.basicText`, пристрій з умовами "Gemini Intelligence" (12GB+ RAM, флагманський SoC)

---

## Ризики й відкриті питання

- Swift Java interop незрілий — може змінити оцінку Фази 1 під час прототипування
- ML Kit GenAI APIs у статусі Beta — можливі breaking changes до GA
- AICore не дає function calling / structured output "з коробки" — рівень 2 контракту на Android завжди буде емуляцією, не гарантією
- CoreData → Room міграція даних існуючих користувачів (якщо застосунок вже в проді) окремо не покрита цим планом — потребує стратегії міграції/експорту
