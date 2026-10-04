# MeditateAndNote — план портування на Android

> Базується на існуючій DDD-архітектурі (Presentation → Application → Domain ← Infrastructure) з протокольними `DataSource`/`Store` контрактами.

> **Обраний шлях: Swift Core + Kotlin/Compose UI.** Swift SDK for Android (офіційний, swift.org) + `swift-java` для JNI-обгорток. UI не шариться — SwiftUI на iOS, Jetpack Compose на Android.
>
> Рекомендація KMP у попередній редакції документа **скасована**: її єдиним аргументом був `@Observable`, який на той час вважався непідтримуваним. Експеримент 2026-10-02 це спростував (див. «Перевірено експериментом»).

> Додано: 2026-09-30, на основі аналізу структури проєкту (Models/, Services/, Persistence/)
> Редакція: 2026-10-02 — шлях обрано після перевірки тулчейну; Рекомендації 1, 7 і Фаза 1 переписані за результатами тесту

## Принцип

Domain-шар платформо-незалежний за визначенням DDD. Портування — це не переписування логіки, а **додавання нових реалізацій існуючих протоколів** під Android, там де Apple SDK не має прямого аналога.

---

## Рекомендації (на основі аналізу кодової бази)

> Додано: 2026-09-30, на основі аналізу структури проєкту (Models/, Services/, Persistence/)

### 1. Observation framework — перевірено, НЕ є блокером

> **Стара редакція була хибною.** Твердження «`@Observable` не компілюється під Swift SDK for Android, тому обов'язково KMP» **не підтвердилося**.

**Факт (перевірено компілятором, 2026-10-02):** пакет, який імпортує `Observation`, оголошує `@Observable`-клас і публічний протокол з `async throws`, **успішно зібрався** під `aarch64-unknown-linux-android28` і дав `libCore.so`.

`@Observable` використовується в Application-шарі (`StreakTracker`, `ReminderManager`, `SoundSettings`, `AnimationSettings`, `ThemeManager`) — це перестало бути перешкодою.

**Що лишається невирішеним:** `@Observable` зручний для SwiftUI, але **Compose не спостерігає за Swift-об'єктами**. Для Android UI потрібне окреме джерело стану (див. Фазу 4) — `@Observable` залишається iOS-механізмом, а не спільним контрактом стану.

**Рекомендація:** рухатись з обраним шляхом (Swift Core). Абстрактний шар над Observation **не потрібен** — це була б абстракція заради абстракції.

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

### 7. Шлях компіляції — обрано: Swift SDK for Android

KMP розглядався і **відхилений**: єдиним його аргументом був `@Observable` (див. Рекомендацію 1), що не підтвердився. Другий аргумент — «Swift SDK експериментальний» — не витримує: це офіційний шлях swift.org, з інструментарієм, який пройшов перевірку.

| | Swift SDK for Android ✅ обрано | KMP ❌ відхилено |
| --- | --- | --- |
| Домен | лишається на Swift, тести продовжують працювати | переписування на Kotlin + повторне покриття тестами |
| Вартість входу | вже перевірена на цьому Mac | Gradle + KMP-тулінг + подвійна експертиза в команді |
| UI | не шариться (SwiftUI / Compose) | не шариться (SwiftUI / Compose) |
| Власний код | Бізнес-логіка не дублюється — багфікс у домені автоматично діє на обидві платформи | те саме, але ціною переписування |

**Ціна цього вибору (чесно):** бізнес-логіка пишеться на Swift, тож команда, що робить Android UI, мусить читати Swift. Android-реалізації Store/Service пишуться на **Kotlin** (вони живуть у Gradle-модулі, не в Swift-пакеті) — це спільна точка трансферу: контракти читаються з Swift, реалізації пишуться Kotlin.

**Де шлях ламається:** публічний API Core-пакета перетинає JNI-межу. Типи, які `swift-java jextract` не вміє перекласти, неможливо віддати Kotlin. Це найважливіше обмеження — див. «Обмеження JNI-межі».

### 8. Тестові стратегія — golden tests для domain-логіки

Замість дублювання тестів на дві мови — використовувати golden tests: один набір тестових даних → очікуваний результат. Прогнати на обох платформах і порівняти результати. Це гарантує паритет логіки без дублювання коду тестів.

### 9. Простор імен — зберегти контракти незмінними

Усі `<X>DataSource`/`<X>Store` протоколи мають залишитися без змін у Domain-шарі. Реалізації (`RoomNoteDataSource`, `AndroidSoundPlayer`) додаються в Infrastructure-шар під Android.

---

## Перевірено експериментом (2026-10-02)

Тулчейн встановлено і перевірено на цьому Mac. Це **факти**, а не оцінки.

### Що встановлено

| Компонент | Версія / шлях |
| --- | --- |
| Swift toolchain (open source) | 6.4.0-RELEASE, `~/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain` |
| Android SDK bundle | `swift-6.4.0-RELEASE_android.artifactbundle` (checksum звірено з офіційним) |
| NDK | `android-ndk-r30` (2.9 GB розпакований) |
| Підтримувані API levels | 23–36, архітектури `aarch64` / `x86_64` / `armv7` |

### Що компілюється ✅

Перевірено на реальному hello-world пакеті з `Foundation`, `Observation`, публічним `struct Note: Codable, Equatable, Sendable`, `@Observable final class` та `public protocol NoteStore: Sendable` з `async throws`:

```bash
export ANDROID_NDK_HOME="<ndk-r30>"
~/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/swift build \
  --swift-sdk swift-6.4.0-RELEASE_android \
  --triple aarch64-unknown-linux-android28
# → Build complete!  →  libCore.so: ELF 64-bit LSB shared object, ARM aarch64
```

Отже, **Foundation + Observation + Codable + Sendable + async/throws + протоколи працюють під Android.**

### Що лишається неперевіреним ⚠️

- ~~Перелік непідтримуваних `jextract` типів~~ → **виміряно**, див. «Обмеження JNI-межі».
- `Observation` **компілюється**, але `Compose` не спостерігає за Swift-об'єктами — bridge стану не спроєктовано.
- **Жодного коду застосунку ще не компільовано** під Android — тільки синтетичні проби.
- **Нічого ще не запущено на пристрої** — лише компіляція. Рантайм JNI (хто викликає `CompletableFuture`, з якого потоку) не перевірено.

### Три ловушки налаштування

1. **Triple мусить містити API level.** `--triple aarch64-unknown-linux-android` (без цифри) → `No Swift SDK found`. Правильно: `aarch64-unknown-linux-android28`.
2. **`swiftly link` не перемикає поточний shell** — `swift` і далі 6.3.3 з Xcode. Треба викликати бінарник тулчейну напряму (`$TC/usr/bin/swift`).
3. **`swift-java` не збирається тулчейном 6.4** — плагін `StaticBuildConfigPluginExecutable` викликає `swift frontend -print-static-build-config`, і `swift build` перезаписує `DEVELOPER_DIR` на шлях тулчейну, де немає `xcrun`; плагін падає. Робочий варіант: збирати `swift-java` **системним** `swift` (Xcode 6.3.3). Це не заважає — тулчейн генератора ніяк не пов'язаний з тулчейном, що компілює під Android.

---

## Обмеження JNI-межі — виміряно (2026-10-02)

Kotlin бачить **тільки те, що `jextract` вміє перекласти**. Нижче — не оцінки: 10 окремих пробних пакетів, скомпільованих під `aarch64-unknown-linux-android28`, прогнаних через `swift-java jextract --mode jni`.

### Головна небезпека: тихий пропуск

Непідтримувані декларації **не дають помилки**. `jextract` повертає `exit 0`, пише `warning: Failed to import: ...` у лог — і методу просто немає в згенерованому Java. Помилку видно лише тоді, коли Kotlin каже «такого методу не існує», тобто вже під час компіляції Gradle-модуля.

**Наслідок для процесу:** лог `jextract` треба перевіряти в CI так само строго, як вивід компілятора. «Успішний» `jextract` нічого не доводить.

### Виміряно на реальному коді (2026-10-02)

Синтетичні проби пройшли, але вони нічого не кажуть про застосунок. Тому `Models/` і `Services/` скопійовано в реальний SPM-пакет і зібрано під Android.

| Крок | Результат |
| --- | --- |
| `Models/` (25 файлів) як є | ✅ **компілюється під Android без змін** |
| `Services/` (29 файлів) як є | ❌ 8 класів блокерів, нижче |
| Те саме + виправлення | ✅ **40 файлів, 4 063 рядки, 3.0M `.so`, 0 помилок на macOS і Android** |

**Знайдені блокери (чотири з п'яти не були в плані):**

| Блокер | Файлів | Складність |
| --- | --- | --- |
| **`OSLog`** (`os.Logger`) | **12** — включно з `NoteManager`, `NotesRepository`, `AIDraftManager` | Потрібен протокол логування. `swift-log` або власний `LogSink` |
| **`any NoteDataSource` — не-Sendable existential** | 1 (`NoteManager`) | **Помилки `sending ... risks causing data races` при переході в Swift 6 mode.** Лікується одним рядком `protocol NoteDataSource: Sendable`. **Це не особливість Android** — див. нижче |
| **`DateFormatter.weekdaySymbols`** — тип різниться | 2 (`StreakInsightEngine:206,750`) | На Apple `[String]?`, на corelibs `[String]`. `guard let` ламається лише на Android |
| **`URLSession`** без `import FoundationNetworking` | 1 (`RemoteLLMDraftService`) | `#if canImport(FoundationNetworking)` — тривіально |
| **`Config.bundleID`** — `Services` посилається на `Navigation/` | 4 | Порушення шару. Замінити літералом або винести константу |
| **default-аргумент = concrete Store** | 1 (`RemoteLLMDraftService:29`) | `settingsStore: any AIDraftSettingsStore = UserDefaultsAIDraftSettingsStore()` — протокол є, але concrete тип leaks у сигнатурі |
| **`@Observable` без `import Observation`** | 15 | **Видимість макроса модульна:** щойно *хоч один* файл імпортує `Observation`, `@Observable` резолвиться в усьому таргеті. Xcode-проєкт жив на 5 випадкових імпортах; SPM-пакет без жодного — падає. Виправлено явними імпортами |
| Managers → `Persistence` напряму | 7 | `NoteManager`, `StreakTracker`, `MeditationService`, `OnboardingStore`, `AnimationSettings`, `SoundSettings`, `ReminderManager` |

#### Статус: три блокери вже виправлені

Виправлено 2026-10-02, branch `portfix`, злито в `main` (merge `a2e00a9`):

| Блокер | Фікс | Файлів |
| --- | --- | --- |
| `any NoteDataSource` не-Sendable | `protocol NoteDataSource: Sendable` + `@unchecked Sendable` на conformer | 2 |
| concrete Store у default-аргументі | ін'єкція з `AIDraftServiceFactory` | 2 |
| `@Observable` без імпорту | явний `import Observation` | 15 |

iOS build green, **477 tests passed, 0 failures**. Правки дають користь на iOS незалежно від порту.

#### Три різні причини, не одна

Перша версія цього розділу стверджувала, що блокери «невидимі з macOS». **Це було неправильно** — експеримент був змішаний: під час macOS-прогона я вже видалив `NoteManager` з набору файлів. Чисте повторне вимірювання:

| Блокер | Причина | macOS | Android |
| --- | --- | --- | --- |
| `sending ... data races` | **Swift 6 language mode** | **18 помилок** | 24 помилки |
| `DateFormatter.weekdaySymbols` | **swift-corelibs Foundation** | 0 | **4 помилки** |
| `@Observable` без імпорту | **структура модуля** | 0 | 0 |

`NoteManager.swift` дає region-isolation помилки **на macOS теж** — у Swift 6 mode. У Swift 5 mode: macOS 0, Android 0. Справа не в платформі.

**`DateFormatter.weekdaySymbols`** — справді платформна різниця: Apple Foundation дає `[String]?`, corelibs — `[String]`. Перевірено окремо в Swift 5 mode, тож незалежно від мови. Портний фікс — перегрузка без warning-ів:
```swift
@inline(__always) func nonNilSymbols(_ v: [String]?) -> [String] { v ?? [] }
@inline(__always) func nonNilSymbols(_ v: [String]) -> [String] { v }
```

#### Проєкт тепер живе в Swift 6 mode

`SWIFT_VERSION = 6.0` у всіх шести конфігураціях Xcode-проєкту, разом з
`SWIFT_APPROACHABLE_CONCURRENCY = YES`. Міграція зроблена на iOS 2026-10-02
(branch `swift6`, merge `84a5b08`): 477 тестів проходять, sendability-попереджень — нуль.

Це закрито той самий клас region-isolation помилок, який інакше вистрілив би одразу
в SPM-пакеті з `swift-tools-version:6.0`.

#### Аудит решти Store/Service-протоколів: перша версія була неповною

Скриптовий аудит по 4 actor-ах і 20 не-Sendable протоколах показав, що **Жоден** з них
не тримається actor-ом, і на цьому було зроблено висновок «робити нічого не треба».

**Цей висновок був хибним.** Скрипт перевіряв лише «хто тримає existential», але
`@MainActor` ViewModel-и теж передають його в `async`-методи — і під Swift 6 mode це теж
перетин isolation-межі. Реальна збірка показала `sending 'self.manager' risks causing
data races` у `ReminderSettingsSection`, `NoteManager`, `NoteInsightManager`, `AIDraftManager`.

Висновок, який тепер підтверджений компілятором: **Sendable-конформанс треба додавати
там, де existential реально перетинає isolation boundary, а `Sendable` не робити
бездумно масово.** Підтверджені зміни:

| Протокол / тип | Причина |
| --- | --- |
| `NoteProvidable` / `NoteManageable` | existential передається в `@MainActor` ViewModel-и з `await` |
| `NoteInsightProvidable` / `NoteInsightManageable` | те саме, `NoteInsightsViewModel` |
| `AIDraftProvidable` / `AIDraftManageable` | те саме, `NoteEditorViewModel` |
| `Destination`, `PushDestination`, `MeditationDuration` | асоційовані значення в `Sendable`-типі |
| `DeepLinkParser.parse` | `@Sendable`-closure, що зберігається |

Плюс `@MainActor` на UI-синглтонах (`AnimationSettings`, `SoundSettings`, `SoundPlayer`)
та `@unchecked Sendable` на immutable-контейнерах (`AppContainer`, `CoreDataManager`).

**Чому `SWIFT_APPROACHABLE_CONCURRENCY` важливіший за ручну розсипку `@MainActor`:**
async-функції успадковують ізоляцію викликача, тому `await` на `@MainActor`-коді з
`@MainActor`-контексту більше не вимагає переходу. Перевірено експериментально: з
цим прапорцем 8 помилок `sending 'self.manager'` у `ReminderSettingsSection` зникли
**без** жодної зміни в `ReminderManager`.

#### Правило, яке себе виправдало

Concrete Store не можна упоминати в сигнатурі Service — навіть як default-аргументом. Точка, де concrete тип дозволений, — **Application-шар** (`AIDraftServiceFactory`). Перевірено: `RemoteLLMDraftService` вже мав `any AIDraftSettingsStore` у властивості, але `= UserDefaultsAIDraftSettingsStore()` у default-аргументі знову вносив Concrete у шар, який не має про нього знати.

#### Три осі хибної «зеленості»

Усі три перевірені експериментом (див. таблицю вище): **мова** (Swift 5 → 6), **платформа** (Apple Foundation → corelibs), **структура модуля** (хтось імпортує `Observation` чи ні).

Green на iOS/Xcode не доводить нічого про порт.



**Це головний висновок вимірювання.** Найстрашніші знайдення — ті, що компілюються на Mac і падають лише на Android. Обидва перевірено: одна й таса ж код, той самий тулчейн 6.4, macOS — 0 помилок.

1. **`any NoteDataSource` не-Sendable** → 24 помилки region-isolation лише на Android.
   `protocol NoteDataSource: Sendable` — один рядок, усі 24 зникли. Перевірено.
2. **`DateFormatter.weekdaySymbols`** — `[String]?` в Apple Foundation, `[String]` у swift-corelibs. `guard let` компілюється на iOS, падає на Android.
   Портний фікс — перегрузка на два випадки, без warning-ів:
   ```swift
   @inline(__always) func nonNilSymbols(_ v: [String]?) -> [String] { v ?? [] }
   @inline(__always) func nonNilSymbols(_ v: [String]) -> [String] { v }
   ```

**Правило:** будь-яка перевірка «портується» має виконуватися на Android-тулчейні. Green на macOS нічого не доводить.

#### Про `OSLog.privacy`

`"\(value, privacy: .public)"` — це не API, а магія компілятора через `ExpressibleByStringInterpolation`. Простий протокол логування її не підхопить; shim-у довелося реалізувати `StringInterpolationProtocol`. У коді — **всього 2 місця**, тож не блокер, але видно, що «замінити імпорт» не вийде.

#### Підсумок вимірювання

Після усіх виправлень:

| | |
| --- | --- |
| Файлів у core | **40** (`Models/` + `Services/`) |
| Рядків | **4 063** |
| `.so` | **3.0M** (динамічна) — проти 512K синтетичної проби |
| macOS, swift 6.4 | ✅ 0 помилок |
| Android, swift 6.4 | ✅ 0 помилок |

Поза ядром лишилися 3 файли, яким потрібна справжня ін'єкція протоколів, а не видалення: `ReminderManager`, `StreakInsightManager`, `AIDraftServiceFactory`.

**Найважливіше:** сім з восьми блокерів — механічні, разом ~25 рядків. Справжня робота — останній рядок: 7 Manager-ів залежать від конкретних `UserDefaults`/`CoreData` реалізацій, що прямо заборонено правилами проєкту. Це не обхід, а те, що DDD вимагав зробити в anyways.

### Що перекладається ✅

| Можливо | Згенерований Java |
| --- | --- |
| `struct: Codable, Sendable` | `Note.java` з `init(...)` |
| `enum` (і з associated values) | звичайний Java-enum / клас |
| Масив, словник, `Optional` | `Note[]`, `SwiftDictionaryMap<K,V>`, `java.util.Optional<T>` |
| `Date`, `UUID`, `Data` | `java.util.Date` тощо |
| `async throws` | `CompletableFuture<T>` |
| `actor` | клас + `CompletableFuture<Void>` на кожен метод |
| Existential **як параметр** | `<_T0 extends NoteStore> run(_T0 store)` |
| Existential **як return** | `NoteStore makeStore(...)` + окремий `NoteStore.java` (interface) |
| Existential **як stored property** | через `init` з generic-параметром |

Актор, `@MainActor`-подібна ізоляція й existential-протоколи — **не проблема**. Це було відкрите питання, тепер закрите.

### Що НЕ перекладається ❌

| Не підтримується | Причина в лозі | Наслідок для `MeditateAndNote` |
| --- | --- | --- |
| **Generic-метод** `<T: Encodable>` | `unknown(IdentifierTypeSyntax)` | `generateStructured<T: Generable>` — **не проходить**. Потрібен не-generic варіант під конкретний тип |
| **`AsyncStream<T>`** | `unknown(IdentifierTypeSyntax)` | `DomainEventBus`, стріми нотисок — **не проходять**. Потрібне інше рішення (див. нижче) |
| **Клоузур** `(@Sendable (Note) -> Void)` | `unimplementedType(AttributedTypeSyntax)` | Callback-подій не перекласти. Замість closure — інтерфейс-протокол |

### Найважливіший наслідок: `AsyncStream` не перекладається

`DomainEventPublisher` побудований на `AsyncStream<DomainEvent>` — отже, **його не можна віддати Kotlin як є**. Розв'язок нижче.

### Розв'язок, перевірений end-to-end

**Форма вже є в проєкті.** `EventLoopCoordinator` визначає `protocol DomainEventRouting { func handle(_ event: DomainEvent) async }` — це рівно та форма, яка потрібна. Транспорт неправильний, не контракт.

Заміна — протокол- підписка замість стріму:

```swift
public enum DomainEvent: Sendable { /* ... */ }

public protocol DomainEventSubscriber: AnyObject, Sendable {
    func handle(_ event: DomainEvent)
}

public final class DomainEventBus {
    private var subs: [UUID: any DomainEventSubscriber] = [:]
    public func subscribe(_ s: any DomainEventSubscriber) -> UUID
    public func unsubscribe(_ id: UUID)
    public func publish(_ e: DomainEvent)
}
```

**Перевірено:** проба K-eventbus (повний `DomainEvent` enum з associated values + підписка) пройшла `jextract --mode jni` без жодного пропуску, а згенеровані Swift-thunk — компіляція під `aarch64-unknown-linux-android28` разом із рантаймом `SwiftJava` → `libCore.so`.

| Swift | Згенерований Java |
| --- | --- |
| `public enum DomainEvent` | `DomainEvent.java` зі static-фабриками на кейс + `Discriminator` |
| `protocol DomainEventSubscriber` | `interface DomainEventSubscriber { void handle(DomainEvent) }` |
| `subscribe(_ s: any DomainEventSubscriber)` | `<_T0 extends DomainEventSubscriber> UUID subscribe(_T0)` |
| `publish(_ e: DomainEvent)` | `void publish(DomainEvent)` |

### Що це дає по кожній проблемі

| Проблема | Рішення | Роботи в коді |
| --- | --- | --- |
| `AsyncStream` | `DomainEventSubscriber` (протокол) | 1 протокол + шина; 3 споживачі міняють `for await` на реєстрацію |
| Клоузури | Те саме — `handle(_:)`. Closure-API шини **видалити** | `subscribe(_ handler:)` має **0 викликів** — мертвий, видалити разом з `AsyncStream` |
| Generic-методи | **Нічого робити** | У `Models/`+`Services/` **нуль** generic-методів |

**Де типовічно:** `DomainEventRouting` вже є протоколом — тож реалізація для Android це Kotlin-клас, що імплементує згенерований Java-інтерфейс. Спільна форма контрактів не роздвоюється.

### Чому проблема з дженериками виявилась не проблемою

`generateStructured<T: Generable>` / `StructuredAIWritingService`, які планували як небезпеку, **у коді відсутні** — вони були гіпотетикою Фази 3. Жоден generic-метод у `Models/` чи `Services/` не існує.

Додатково перевірено й **відкинуто** запропонований type-erasure: `func f(_ v: any Encodable)` теж **не перекладається** (пропускається разом із generic-варіантом). Тобто escape hatch «замінити `<T>` на `any P`» не існує — прийняття проєкту: не вводити generic-методи в публічний API ядра.

### Справжня вартість: каскад `public`

Щоб `DomainEvent` перекладався, він мусить бути `public`, а з ним — увесь ланцюг типів, які він згадує (`Note`, `NoteID`, `MeditationSession`, `AIDraftMetric`).

**Виміряно:** у `Models/` **58 типів без `public`, 1 з `public`**. Тобто майже весь домен треба зробити `public`.

Це механічна, односпрямована зміна (не ламає iOS), але вона торкається майже кожного файлу в `Models/`. **Робити її до того, як створено SPM-пакет `MeditateAndNoteCore`, не можна** — інакше доведеться робити двічі.

### Правило для публічного API ядра

> Публічний API `MeditateAndNoteCore` не може містити: generic-методів, `AsyncStream`, клоузур і макросів. Усе інше з переліку вище — можна.
>
> Це означає, що доменний Swift-код лишається **нормальним Swift-кодом** (генеріки й клоузири в ньому лишаються), а JNI-сумісна поверхня — окремий шар `CoreAPI`, який збирається з перевірених типів.

---

## Чек-лист: що перевірити далі

Відсортовано за тим, наскільки невідома відповідь блокує наступний крок. Позиції 1–4 **не** робляться без Android-пристрою або без зміни коду.

### 1. Рантайм JNI на пристрої — найбільший невідомий

**Стан:** Tier 1 (Swift runtime) ✅ і Tier 2 sync (JNI bridge) ✅ **підтверджено на пристрої** (Samsung A24, Android 16, API 36, arm64-v8a). Залишилося: `async` → `CompletableFuture` і протокол- підписка.

#### Tier 2 — що встановлено (2026-10-03)

Sync JNI пройшов end-to-end через справжній ART на пристрої: `struct` + `String` через `SwiftArena`, `enum` з associated values, 1000 ітерацій — crash/leak немає.

**Розгортання без Gradle — 4 кроки** (корисне і для Фази 1):

```bash
aapt2 link -o base.apk -I android.jar --manifest AndroidManifest.xml \
  --min-sdk-version 28 --target-sdk-version 36
zip base.apk classes.dex && zip -r base.apk lib
zipalign -p -f 4 base.apk aligned.apk
apksigner sign --ks debug.keystore --ks-pass pass:android aligned.apk
```

**Дві ловушки, що коштували час:**

| Ловушка | Симптом | Причина |
| --- | --- | --- |
| `libc++_shared.so` **не в Swift SDK** | `UnsatisfiedLinkError: dlopen failed: library "libc++_shared.so" not found` | Береться з NDK: `$NDK/toolchains/llvm/prebuilt/*/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so`. Разом з ним тягне `libswiftSwiftOnoneSupport.so`, `libswiftCore.so` — тобто весь ланцюг. |
| `libSwiftJava.so` + `libSwiftRuntimeFunctions.so` — це `DT_NEEDED` для `libCore.so` | та сама помилка, але на `libSwiftJava.so` | `SwiftLibraries.loadLibraryWithFallbacks` вантажить їх за іменем; вони **не** входять у Swift SDK, а збираються як `.dynamic` продукти `swift-java` — і лежать у `.build/out/Products/<triple>/`, а не в SDK-ресурсах |

`app_process64` як спосіб запуску **не працює** на Android 16: ART ініціалізується, потім процес тихо отримує `SIGKILL` без crash-трейсу (перевірено з `ANDROID_DATA` у writable-каталозі). Не витрачати на це час — APK.

**Що лишилося невідомим у Tier 2:**

- **Хто завершує `CompletableFuture`.** `async` → `CompletableFuture`; який потік виконує `future.complete(...)`.
- **Зворотний виклик об'єкта.** `subscribe(_T0 s)` → thunk `load(as:) as! (any Subscriber)`. GC/lifetime.
- ~~`SwiftArena` і власність~~ → ✅ sync-шлях перевірено (arena закриваєтьсяtry-with-resources, crashів немає). Async-шлях із `Arena` у життєвому циклі future — ще ні.

### 2. `Foundation`-семантика, не компільованість

**Стан: ✅ ПЕРЕВІРЕНО golden-дифом (2026-10-03). 145 рядків, 0 розбіжностей.**

Один Swift-файл (144 спостереження) зібрано під macOS і під `aarch64-unknown-linux-android28`, запущено на Samsung A24, вивід записано `key|value` рядками. Диф двох файлів: **єдиний відмінний рядок — `platform`**. Уся решта — побайтово однаково.

Обкрите: tz database (443 зони, offsets для 8 зон), DST gap/fold для Kyiv/London/NY, портований дослівно `ReminderScheduleBuilder.nextFireDates`, місячна/річна арифметика, `startOfDay`, `firstWeekday`/`minimumDaysInFirstWeek` для 7 локалей, `DateFormatter` (включно з арабськими/тайськими цифрами), `ISO8601DateFormatter`, `Date` Codable, `Double`/`Float` description, `localizedCaseInsensitiveCompare`, `NumberFormatter`, 8 `Calendar.Identifier` (.chinese/.islamic/.hebrew/.japanese/.coptic).

**Наслідок:** `ReminderSettingsTests` і `StreakInsightEngineTests` можна ганяти на Android очікуючи той самий результат. Golden-тести Фази 1 не потребують окремої Android-версії очікувань.

Три знахідки, які треба врахувати в коді, а не в тесті:

| Знахідка | Симптом | Наслідок |
| --- | --- | --- |
| `TimeZone(identifier: "Asia/Cairo")` | **nil** | `Africa/Cairo` працює. Неофіційний alias — не спиратись |
| `Calendar.date(from:)` з `hour: 3, day: 31, month: 3`, `Europe/Kyiv` | **НЕ nil** — нормалізує до `hour: 4` | DST-gap **не відсікається** через `date(from:)` — повертається *інша* година. Не перевіряти `nil`, а брати `startOfDay` і додавати години через `date(byAdding:)` (як робить `ReminderScheduleBuilder`) |
| `Calendar.date(from:)` з `hour: 24` / `hour: 25` | **НЕ nil** — нормалізує до `hour: 0` / `hour: 1` **наступного дня** | Межа дня теж не відсікається, а тихо зсуває дату. Не призначати `hour` ≥ 24 напряму з розрахунку DST |
| `DateFormatter.date(from:)` для неіснуючої локальної години (`"2024-03-31 03:00"`, Kyiv) | **nil** | Рядковий парсинг DST-gap **повертає nil** — на відміну від `Calendar.date(from:)`. Різні APIs, різні контракти: не переносити висновок з одного на другий |

Перевірено окремим прогоном на Swift 6.4 (macOS): DST-день 2024-03-31, `Europe/Kyiv`.
`Calendar.date(from:)` нормалізує замість nil; `DateFormatter.date(from:)` повертає nil.
Обидва API мають збігатися на Android — golden-диф це й підтверджує (рядки `dst.gap.*`).

> Раніше в цій таблиці було записано, що `date(from:)` повертає nil для `hour: 3` і `hour: 25`.
> Це було **неправильно** — вивід отримано з помилкового діагнозу: panic у golden-пробі
> виникав на `TimeZone(identifier: "Asia/Cairo")!` (nil), а не на `hour: 25`.
> `hour: 25` не був доведений до кінця і виявився не-nil. Виправлено 2026-10-03.

Golden-файли: `probes/F-foundation/Sources/FProbe/main.swift`. Відтворювано:
```bash
# macOS baseline
swift build -c release && ./.build/release/FProbe > /tmp/f_macos.txt
# Android
swift build -c release --scratch-path .build-android \
  --swift-sdk swift-6.4.0-RELEASE_android --triple aarch64-unknown-linux-android28
adb push .build-android/out/Products/Release-android-aarch64/FProbe /data/local/tmp/
adb shell "LD_LIBRARY_PATH=/data/local/tmp ./FProbe" > /tmp/f_android.txt
diff /tmp/f_macos.txt /tmp/f_android.txt
```

> **Ловушка:** `--scratch-path` обов'язковий. Без нього macOS-збірка перезаписує Android-бінарь (обидва в `.build/out/Products/`), і на пристрій їде Mach-O — `syntax error: unexpected '('`. Шлях Android-збірки має суфікс `-android-aarch64`.

### 3. Каскад `public` — 58 типів

**Чому не перше:** механічна робота без невідомих, але **робити до створення SPM-пакета марно** — доведеться двічі. Робити одразу після Фази -1, крок 1.

**Перевірка після:** iOS-збірка лишається зеленою, тести 469/469 без змін (після додавання 6 тестів шини — 475/475).

### 4. Семантика нової шини

**Стан: ✅ ПЕРЕВІРЕНО (2026-10-03).**

`AsyncStream` давав кожному споживачеві **послідовність у порядку публікації**. Протокол- підписка цього не дає — тому контракт треба зафіксувати тестом *до* заміни.

Контракт, який тримають `EventLoopCoordinator`, `NoteMenuViewModel`, `NoteInsightsViewModel`:

| Гарантовано | Не гарантовано |
| --- | --- |
| кожен споживач бачить події **в порядку публікації** | порядок виклику *різних* споживач між собою |
| усі споживачі бачать **однакову** послідовність | |
| `unsubscribe` зупиняє доставку з цієї точки | |

Другий стовпчик невипадковий: `Subscriptions` тримає handler-и у `Dictionary`, `publish` робить `Array(handlers.values)` — порядок обходу нестабільний між запусками. На це не спирається жоден виклик.

Тест: `MeditateAndNoteTests/DomainEventBusOrderingTests.swift`, 6 тестів × 100 подій — `subscribe(_:)` шлях, `AsyncStream` шлях (3 одночасні consumers), конкурентний publish з двох потоків, unsubscribe. **6/6 green**, повний suite **483/483** (475 unit + 8 UI).

Ці тести — acceptance criteria для заміни: вони мають пройти **без змін** проти реалізації на `DomainEventSubscriber`.

Дві речі, які тести зловили під час написання (обидві в тесті, не в продукті):
- `AsyncStream` — **single-consumer**. Три таски, що поділяють один інстанс, ділять між собою елементи: жоден не добирає своєї кількості → deadlock. Кожен споживач мусить брати свій `bus.events`.
- Порядок реєстрації continuation-ів не можна закладати на `Task.sleep`. `bus.events` реєструє continuation синхронно в getter-і, але сама `Task` ще не запущена — батьківський publish без suspension point втратить всі події. Тест uses `ArrivalGate`: consumer бере stream, **потім** повідомляє про готовність; publisher чекає на `count` arrivals.

> Стан тимчасово: `DomainEventBus` ще на `AsyncStream`. Тести — на майбутню реалізацію.

### 5. Скільки бойлерплату пише Kotlin-реалізатор

**Стан: ✅ ВИРІШЕНО. Kotlin-реалізатор пише ОДИН метод (2026-10-03).**

Розгадка — прапорець `jextract --enable-java-callbacks`, якого не було в першій пробі. Без нього генератор вважає, що протокол реалізує лише Swift, і додає `JNISwiftInstance` (умова в `JNISwift2JavaGenerator+JavaBindingsPrinting.swift:197`):

```swift
// If we cannot generate Swift wrappers that allows the user to implement
// the wrapped interface in Java then we require only JExtracted types can conform
if !self.interfaceProtocolWrappers.keys.contains(decl) && !extends.contains("JNISwiftInstance") {
    extends.append("JNISwiftInstance")
}
```

**Без** прапорця:
```java
public interface DomainEventSubscriber extends JNISwiftInstance, SwiftDowncastable { ... }
```

**З** прапорцем:
```java
public interface DomainEventSubscriber extends SwiftDowncastable {
  public void handle(DomainEvent event);
}
```

Kotlin-реалізатор — усе:

```kotlin
class LoggingSubscriber : DomainEventSubscriber {
    override fun handle(event: DomainEvent) { println("Kotlin got: $event") }
}
```

Скомпільовано `kotlinc 2.3.20` (з Android Studio) проти згенерованого Java — **без помилок**. Жодних `$*` методів.

Thunk тепер має дві гілки (`Core+SwiftJava.swift`, `subscribe`):

```swift
if environment.interface.IsInstanceOf(environment, s, _JNIMethodIDCache.JNISwiftInstance.class) != 0 {
    // шлях Swift-значення: $memoryAddress + load(as:) + as!  (старий, недосяжний для Java)
} else {
    // шлях Java-реалізатора: Swift-обгортка, handle форвардиться в Java
    sswiftObject$ = _DomainEventBus_subscribe_s_Wrapper(
        _javaDomainEventSubscriberInterface: JavaDomainEventSubscriber(javaThis: s!, environment: environment))
}
```

Гілка `else` — та сама `_DomainEventBus_subscribe_s_Wrapper: SwiftJavaDomainEventSubscriberWrapper`, що її генерує jextract. Жодного `$memoryAddress`, жодного `as!`, жодної metadata.

**Потрібні ДВА кроки, не один.** `jextract --mode jni --enable-java-callbacks` генерує Java-інтерфейс (`DomainEventSubscriber`) і Swift-thunk'и, які посилаються на `JavaDomainEventSubscriber` — але самого класу `JavaDomainEventSubscriber` він **не** пише. Його дає `wrap-java` (через `configure`), тобто фаза `java-callbacks-build`. Прапорця самого `jextract` недостатньо: без фази 2 компілятор падає з `cannot find type 'JavaDomainEventSubscriber' in scope`.

**Обмеження прапорця** (з `--help`): вимагає вимкнення SwiftPM Sandbox (`--disable-sandbox`). Під час інтеграції з SPM це окрема налаштовка.

Gradle 9.8.0 встановлено через brew — знадобиться для Фази 1 (Gradle-модуль Android, `jniLibs`). Для поточної задачі не знадобився.

**Висновок для дизайну шини:** варіант «Kotlin реалізує `DomainEventSubscriber`» **живий**, попередній негативний результат був артефактом відсутнього прапорця.

**СТАТУС: callback round-trip ПЕРЕВІРЕНО (2026-10-04).** `swift-java` був уже зібраний у `sjpull/swift-java/.build/arm64-apple-macosx/release/swift-java` — його просто не було в `PATH`, тому й здавалося, що інструмент недоступний. JBR від Android Studio (`/Applications/Android Studio.app/Contents/jbr`, JDK 25) дає `javac`; системного JDK у системі немає.

Перевірено на host-JVM (справжній JNI, справжній GC), probe `K-eventbus`:

| питання | результат |
| --- | --- |
| `subscribe` → `publish` → callback у Java | ✅ спрацьовує, обидва підписники отримали подію |
| `unsubscribe` | ✅ після нього другий publish дістав лише alive-підписника |
| **GC/lifetime** | ✅ підписник пережив 5× `System.gc()` після втрати Java-покликань. Swift-шина тримає strong ref через box — **explicit retain не потрібен** |
| **Потік callback** | ✅ `main`, коли публікує main; `worker-1`, коли публікує інший потік. Тобто **на потік емітера**, без маршалингу |
| `UUID` мапінг | ✅ `java.util.UUID.fromString` → Swift `UUID` і назад; але Swift `UUID.description`uppercase, тому назад приходить `...-AAAAAAAAAAAA`. Якщо порівнювати рядки — врахувати регістр |

Згенеровані Java-типи не потребують жодних `$memoryAddress`/`$typeMetadataAddress`/`$cleanup` stubs — їх дає макрос `@JavaInterface` на Swift-стороні. Раніший рукописний stub-файл був зайвим.

**Розмір callback-closure:** статична `libCore.so` з callbacks — **78 MB** (dynamic-хости: 4.2 MB `libCore.dylib` + `libSwiftJava.dylib`). Порівняно з 8.1 MB без callbacks: `@JavaInterface`/`JavaObject` тягнуть повний `Foundation` closure разом з ICU. Це та сама ціна, яку доведеться заплатити за `DomainEventSubscriber`.

**Перевірено на реальному пристрої** Samsung SM-A245F, Android 16 / API 36, arm64-v8a — APK `com.probe`, статична `libCore.so` (78 MB) + `libc++_shared.so` (9.5 MB).

| крок | результат |
| --- | --- |
| `subscribe` × 2 → `publish(noteCreated)` | ✅ обидва підписники отримали подію (count=2) |
| `unsubscribe(A)` → `publish(noteDeleted)` | ✅ count=3 — лише alive-підписник |
| GC-стрес: 5× `System.gc()` + `Thread.sleep` | ✅ count=4 — підписник живий після втрати Java-покликань |
| `UUID` мапінг | ✅ `...-AAAAAAAAAAAA` — Swift повертає uppercase |

Час старту: `am start -W` → `WaitTime: 609 ms`, сам probe (dlopen 78 MB + JNI + publish) → `elapsedMs=446`.

**Дві обов'язкові пост-обробки для статичної Android-збірки** (обидві впали на пристрої, обидві виправлені):

1. **Згенерований Java завжди намагається завантажити `libSwiftJava.so`** — `static { SwiftLibraries.loadLibraryWithFallbacks(SwiftLibraries.LIB_NAME_SWIFT_JAVA); ... }`. При статичному лінкуванні цієї бібліотеки немає, тому падає `dlopen failed: library "libSwiftJava.so" not found`. Прапорця в `jextract` немає — рядок треба вирізати з.generated Java (8 файлів у probe). Альтернатива — класти `libSwiftJava.so` окремо, але це +9 MB даремно.
2. **`--static-swift-stdlib` не робить бібліотеку самодостатньою** — `libCore.so` все одно має `NEEDED libc++_shared.so`. Його треба класти в `lib/arm64-v8a/` (є в NDK r30: `sysroot/usr/lib/aarch64-linux-android/libc++_shared.so`, 9.5 MB).

**Лишається неперевіреним:** `CompletableFuture` — async-функцій у probe немає, тож нитка про потік завершення callback лишається відкритою.

### 6. Розмір `.so` та час старту

**Стан: ✅ ВИМІРЯНО (2026-10-03). Число неприємне, але кероване.**

Попередня оцінка «синтетична проба 512K» була нерелевантна — вона рахувала лише власний код, не рантайм. Виміряно транзитивний closure через `llvm-readelf -d`.

**Динамічна лінковка: 98.9 MB uncompressed.** Closure від `libCore.so` + `libSwiftJava.so`:

| .so | MB |
| --- | --- |
| `lib_FoundationICU.so` | **43.7** |
| `libswiftCore.so` | 11.1 |
| `libFoundationEssentials.so` | 10.0 |
| `libc++_shared.so` | 9.0 |
| `libFoundation.so` | 8.6 |
| `libSwiftJava.so` | 6.9 |
| `libFoundationInternationalization.so` | 3.6 |
| інші 13 | ~5.4 |

`lib_FoundationICU.so` — **hard NEEDED** обома (`libFoundation.so`, `libFoundationInternationalization.so`), не dlopen. Перевірено: 5444 експортовані функції, нуль залежностей від системного ICU → це повний статичний білд ICU, вбудований у toolchain. Обрізати неможливо.

**Попередній APK у 39.3 MB був спакований надлишково** — кожна `.so` з каталогу toolchain підряд, а не closure. Не лінкуються ні `libFoundationNetworking.so` (15.7 MB), ні `libXCTest`/`libTesting` (4.2 MB).

**Статична лінковка — головний важіль.** `swift build -c release --static-swift-stdlib`:

| збірка | розмір | ICU |
| --- | --- | --- |
| динамічний closure | 98.9 MB | повний |
| статична, мінімум Foundation (K-eventbus) | **8.1 MB** | вирізано (0 маркерів) |
| статична, Foundation-heavy (FProbe) | **65 MB** | повний (4877 маркерів) |

Перевірка «ICU вирізано» — не за експортами, а за вмістом: у 8.1 MB немає жодного маркера `icudt`/`ures_open`/`ucnv_open` і жодного `Europe/Kyiv`; у 65 MB їх 4877 і tzdb присутній. Тобто `--gc-sections` працює, але те, що Foundation реально використовує, лишається.

**Що це означає для `MeditateAndNoteCore`.** Реальне ядро потребує `DateFormatter`, `Calendar`, `TimeZone`, `NumberFormatter` (`ReminderScheduleBuilder`, `StreakInsightEngine`) — тобто **повний ICU**. Очікування: **~65 MB до власного коду застосунку**, плюс Compose, ресурси, DEX.

Це не блокер, але це головний ризик розміру й має бути в бюджеті застосунку з дня 1. Варіанти поменшення, якщо стане критично:
- не тягнути `NumberFormatter`/локалізацію в Core (інакше ICU не виріжеться)
- AAB + per-device split — але ICU все одно в кожному split
- окремий «легкий» Core без часових шарів Foundation

Час старту **не виміряно** — потрібен реальний APK. Планується разом із Фазою 1.

### Вже закрито — не перевіряти заново

- ✅ `Models/` компілюється під Android без змін
- ✅ межа JNI (12 проб), зокрема несумісність `AsyncStream`/клоузур/generic
- ✅ розв'язок через протокол- підписку — Java + thunk компілюються
- ✅ `any Encodable` type-erasure **не** працює (відхилено)
- ✅ Swift runtime завантажується на Android 16 arm64-v8a (1000 ітерацій, PASS)
- ✅ **sync JNI bridge на пристрої** — struct/enum через `SwiftArena`, 1000 ітерацій, PASS; розгортання без Gradle
- ✅ **Kotlin-реалізатор subscriber-а = 1 метод** — `jextract --enable-java-callbacks` (див. п. 5)
- ✅ **розмір runtime** — статична лінковка дає 8.1 MB мінімум / 65 MB з повним ICU (див. п. 6)
- ✅ **`Foundation`-семантика — golden-диф macOS ↔ Android, 145 рядків, 0 розбіжностей** (DST, локалі, календарі, формати)
- ✅ JNI thunks `--mode jni`, 51 `Java_*` символ у `.so`
- ✅ `swift-java` зібрано (виправлено `DEVELOPER_DIR`/toolchain)
- ✅ FFM mode (дефолт `swift-java jextract`) — **непридатний для Android** (потребує `java.lang.foreign`)
- ✅ блокери реального коду повністю перелічені вище

---

## Фаза -1 — Аналіз переносу в Core (перше, що робиться)

Мета: перевірити компілятором, а не на око, наскільки Domain+Application реально чисті, перш ніж писати будь-який план далі як факт.

**Вже виміряно (без оцінок, 2026-10-02):**

| Метрика | Значення |
| --- | --- |
| Кандидат у ядро (`Models/` + `Services/` + `Persistence/`) | 54 файли / 5680 рядків |
| `Views/` + `ViewModels/` (не портуються — UI дублюється) | 48 файлів / 7475 рядків |
| Файлів з Apple-специфічними імпортами в `Models/` | **0** |
| SPM-залежностей у проєкті | 0 |

Тобто ~35% рядків коду — ядро, ~44% — UI. Порядок зусиль зрозумілий: UI дублюється (Compose з нуля), ядро переноситься без змін.

- [x] ~~Скомпілювати під `aarch64-unknown-linux-android28` — зафіксувати кожну помилку як приховану залежність~~ — **ВИМІРЯНО 2026-10-03 див. нижче**
- [x] ~~Для кожної знайденої залежності вирішити: абстрагувати чи визнати платформо-специфічною~~ — **вирішено, див. «Приховані залежності»**
- [x] ~~Створити локальний SPM-пакет `Packages/MeditateAndNoteCore`~~ — **зроблено 2026-10-03**, ітерований у `project.pbxproj` як `XCLocalSwiftPackageReference`
- [x] ~~Перенести `Models/` у пакет першими~~ — **зроблено**: 25 файлів, 59 публічних типів
- [ ] Перенести `Services/` (Managers) — складніша частина, більше протокольних меж

#### Каскад `public`: що реально довелось зробити

Головна робота — не `git mv`, а доступність. Виміряно по ходу:

| категорія | кількість | примітка |
| --- | --- | --- |
| типи без `public` | 58 | лише `MeditationDuration` був публічний |
| явні `public init` | 11 | див. нижче |
| `Sendable`, доданий вручну | 8 | див. нижче |
| `import MeditateAndNoteCore` в app-файлах | 69 | тільки там, де реально є Core-типи |
| `import MeditateAndNoteCore` у тестах | 37 | усі `@testable import` |

**Найбільша неочікувана знахідка: синтезований memberwise `init` для `public struct` лишається `internal`.** Довелось написати 11 явних `public init` — інакше зовнішній модуль не міг створити `DailyActivity`, `StreakSnapshot`, `StreakInsight`, `WeekdayHeatmapData`, `StreakResilience`, `StreakLengthDistribution`, `StreakDayDetail`, `UserRecommendation`, `BreathingPattern`, `BreathingPhase` і два вкладені (`Day`, `Bucket`). Для `StreakInsight`/`UserRecommendation` довелось також змінити `let id = UUID()` на `let id: UUID`, бо `let` з початковим значенням не перепризначається в `init`.

Другий неочікуваний наслідок: **`public` змушує проявити питання `Sendable`.** Раніше `internal`-типи не перетинали межу модуля, тому компілятор не перевіряв їхню конкурентну безпеку. Піднявши `DomainEvent`, `SearchQuery`, `MeditationSession` до `public`, отримали 8 реальних помилок у Swift 6 strict concurrency. Усі — виправні додаванням `Sendable` до незмінних enum/struct, які цього правда заслуговують (`CoreDayState`, `MeditationID`, `SessionID`, `SessionDuration`, `Meditation`, `MeditationTitle`, `BreathingStyle`, `MeditationCategory`, `SearchQuery`, `NoteFilter`).

**Скриптовий каскад небезпечніший за компілятор.** Regex-скрипт спершу додав `public` у `case` всередині `switch`, у тіла протоколів і на `extension X: P` — усі три місця Swift це відкидає. Роботи довелось робити ітеративно: скрипт для масового підйому + компілятор як джерело правди для всього, що скрипт не бачить. Остаточний стан — 0 помилок і 0 warnings на macOS та Android.

**Перевірено:** пакет збирається окремо під `aarch64-unknown-linux-android28` (0/0) і разом з iOS-застосунком (BUILD SUCCEEDED); 475 unit + 8 UI тестів, 0 помилок.

**Побічний ефект `.gitignore`:** рядок `Packages` у секції SwiftPackageManager ігнорував би **каталог пакета з джерелками**. Xcode тримає свій SPM-кэш у DerivedData, тому рядок не мав призначення — прибрано.

#### Виміряно: приховані залежності від Apple SDK

Метод: реальні файли `Models/` + `Services/` + `ViewModels/` + `UserDefaults*Store` + `Config` скопійовано в тимчасовий SPM-пакет і скомпільовано під `aarch64-unknown-linux-android28`. `import OSLog` замінено на шим. Apple-файли (`CoreData*`, `ThemeManager`, `FoundationModels*`, `NLEmbeddingService`, `KeychainService`, `SoundPlayer`, `NotificationScheduling`) вилучено.

**60 файлів → 19 помилок. З них справжніх Android-SDK — 5, решта 14 вказують на 5 порушень шарів.**

`Models/` — **0 помилок, 0 Apple-залежностей.** Усі 25 файлів лише `import Foundation`, жодного `#if canImport`, жодного `@available`. Перенесення механічне; єдиний реальний блокер — access level.

Справжні Android-SDK розбіжності:

| # | Файл | Проблема | Рішення |
| --- | --- | --- | --- |
| 1 | `Services/AI/RemoteLLMDraftService.swift` | `URLSession`/`URLRequest`/`URLResponse` живуть у `FoundationNetworking` | `#if canImport(FoundationNetworking)` |
| 2 | `Services/Streak/StreakInsightEngine.swift:206,750` | `DateFormatter.weekdaySymbols` на Darwin — `[String]!`, на Android — `[String]`. `guard let fullSymbols = ...` не компілюється | прибрати `guard let` |

Порушення шарів (ViewModel → View, або Manager → конкретна платформна реалізація):

| Файл | Проблема | Що зроблено |
| --- | --- | --- |
| `RemoteLLMDraftService.swift` | `URLSession`/`URLRequest`/`URLResponse` у `FoundationNetworking` | `#if canImport(FoundationNetworking)` |
| `StreakInsightEngine.swift` (2 місця) | `weekdaySymbols`: Darwin `[String]?`, corelibs `[String]` — `guard let` не компілюється на Android | `?? []`; індексний fallback нижче вже терпить порожній масив |
| `ViewModels/NoteMenuViewModel.swift:23,29` | `SearchState` живе у `Views/NoteMenu/` | файл перенесено в `ViewModels/` |
| `ViewModels/OnboardingViewModel.swift:27,38` | `OnboardingPage` живе у `Views/Onboarding/` | файл перенесено в `ViewModels/`, перейменовано |
| `Services/Reminders/ReminderManager.swift` | протокол `NotificationScheduling` ділив файл з `UserNotifications`-адаптером | протокол винесено в Core, `SystemNotificationScheduler` лишився в app |
| `Persistence/UserDefaultsAIDraftSettingsStore.swift:12,18` | `KeychainServiceProtocol` ділив файл з `Security`-реалізацією | протокол винесено в Core, `KeychainService` лишився в app |

**Дві знахідки виявилися хибними при перевірці, і це важливо:**

1. `ReminderManager` **вже** залежав від протоколу, а не від concrete-типу. Помилка в пробі виникла тому, що видалений файл `NotificationScheduling.swift` містив і протокол, і адаптер — вилучивши файл, ми втратили й протокол. Тобто «замінити concrete на протокол» не було потрібно; потрібно було лише **розділити файл**.
2. `AIDraftServiceFactory` — це **composition root**, а не порушення. Він навмисно вибирає реалізацію через `#available(iOS 26.0, *)`, тобто залежно від можливостей платформи. Такий вибір лишається в app, у Core йому не місце. Android матиме власну фабрику.

## Винесення `Services/` у пакет — перша хвиля (11 файлів)

Перенесено все, що не тягне жодного Apple-only import:

| Файл | Що це |
| --- | --- |
| `Events/DomainEvents.swift` | шина доменних подій, JNI-контракт |
| `Streak/StreakInsightEngine.swift` | чистий engine інсайтів |
| `Streak/StreakInsightManager.swift` | оркестратор інсайтів |
| `AI/AIDraftService.swift`, `AI/AIDraftSessionStore.swift` | protocol + disabled stub |
| `AI/EmbeddingService.swift`, `AI/NoteAnalyzer.swift` | protocol-и |
| `AI/HeuristicNoteAnalyzer.swift` | портативний евристичний analyzer |
| `Meditation/MeditationService.swift` | protocol + `SampleMeditationService` |
| `Onboarding/OnboardingStore.swift` | store protocol + `UserDefaultsOnboardingStore` |
| `Telemetry/AIDraftMetricStore.swift` | store protocol + in-memory |

Залишено в app як composition root або платформну реалізацію: `AIDraftServiceFactory`,
`ThemeManager`, `FoundationModels*`, `NLEmbeddingService`, `KeychainService`,
`SoundPlayer`, `SystemNotificationScheduler`, `RemoteLLMDraftService`, `NoteManager`,
`NotesRepository`, `StreakTracker`, `ReminderManager`, `AIDraftManager`,
`NoteInsightManager`, `SemanticSearchManager`.

`StreakInsightManager` мав `convenience init(streakTracker: StreakTracker)` —
єдину залежність від concrete-типу. Видалено: основний `init` уже приймає
`any StreakSnapshotProvidable`, якого `StreakTracker` реалізує.

**Скрипт каскаду `public` довелось переписати.** Перша версия орієнтувалася на
відступи і вставляла `public` усередині тіл функцій (`HeuristicNoteAnalyzer.swift:17`
набув `public let analyzable` всередині `func analyze`), а також не враховувала, що
`public protocol` не матчить патерн `^protocol`. Друга версия чинила те саме, бо
`^(public\s+)+` не допускав відступу перед `public`. Правильна версия відстежує
**глибину дужок**, а не відступи: `public` дозволений лише на глибині 0 (типи) та
1 (їхні члени), ніколи всередині протоколу, `public extension` чи `enum case`.
Перевірено: другий прогін — 0 файлів, тобто ідемпотентно.

Три типи потребували явних `public init()`, бо синтезований memberwise-`init`
завжди `internal`: `HeuristicNoteAnalyzer`, `SampleMeditationService`,
`DomainEventBus`. `DisabledAIDraftService` — той самий випадок.

Каскадні помилки в `MeditationView.swift` («explicit `return` in `ViewBuilder`»)
виявилися наслідком недоступного `SampleMeditationService()` — компілятор просто
не доходив до перевірки ViewBuilder.

Дві попередження на Android у `StreakInsightEngine` (`?? []` зайвий) — очікувані:
corelibs декларує `weekdaySymbols` як неопціональний `[String]`, тоді як Darwin
має `[String]?`. Ціна за єдиний вислів, який компілюється на обох платформах.

`SearchState` і `OnboardingPage` **не** переносилися в Core: `SearchState` — `@Observable` стан презентації, `OnboardingPage` містить SF Symbol-и. Обидва лишаються в застосунку, але вже не всередині `Views/`, щоб ViewModel не залежав від View-шару. Для Android UI дублюється — їм у Core не місце.
- [ ] Перенести `Services/` (Managers) — складніша частина, більше протокольних меж
- [ ] ~~Усунути виняток `CoreDataSessionStore`~~ — **не робити.** Це задокументований прийнятий виняток (див. архітектурні правила): `CoreDataSessionStore` свідомо працює без Store-протоколу. Для Android-порту це означає лише «зроби окремий адаптер», а не «перероби існуючий тип».
- [x] ~~Прогнати `jextract` на пробному наборі~~ — **зроблено 2026-10-02**: 12 проб, перелік підтримуваних/непідтримуваних типів у розділі «Обмеження JNI-межі»
- [x] ~~Знайти розв'язок для `AsyncStream` і клоузур~~ — **зроблено**: протокол- підписка, перевірена end-to-end (Java + thunk під Android)
- [ ] **Вирішити, коли робити каскад `public`** для 58 типів `Models/` — тільки після створення SPM-пакета, інакше двічі
- [ ] Зберегти семантику «послідовно, у порядку публікації» в новій шині (черга під замком), бо `AsyncStream` давав її кожному споживачеві
- [ ] Перевірити рантайм JNI на пристрої: **async** — хто завершує `CompletableFuture` і з якого потоку приходить Kotlin-об'єкт (sync-шлях ✅)
- [ ] Зафіксувати `swift-java` як версіоновану залежність Core-пакета (thunk без неї не компілюється)
- [ ] Зафіксувати фактичний % переносного коду (замість оцінки "90-95% на око") і звірити з рештою плану — за потреби скоригувати Фази 0-5 нижче

**Результат фази:** підтверджена (не гіпотетична) межа Core/Infrastructure **і** межа JNI-межі, на які спираються всі наступні фази.

---

## Знахідки з аналізу кодової бази

Конкретні ризики, виявлені в наявному коді — враховані вище у Рекомендаціях та Фазі -1, зафіксовані тут для довідки.

- **Доведений патерн градуйованої AI-доступності.** `AIDraftService` вже має три реалізації (`FoundationModelsAIDraftService` iOS 26+, `RemoteLLMDraftService` fallback, `DisabledAIDraftService`); `NoteAnalyzer` — дві (`HeuristicNoteAnalyzer` завжди, `FoundationModelsNoteAnalyzer` iOS 26+). Android-реалізація (`AICoreAIDraftService`) додається як ще один варіант за тим самим контрактом — не новий концепт, а розширення існуючого патерну.
- **`CoreDataSessionStore` без протоколу** — єдиний Infrastructure-компонент без абстракції; без фіксу немає куди підставити Android-реалізацію.
- **`@MainActor`/актори/`AsyncStream`** — базуються на Swift Concurrency, теоретично портовані через мову, але `@MainActor` як концепція головного UI-потоку потребує окремої перевірки рантайм-поведінки на Android (не лише компільованості).
- **`@Observable` в Application-шарі, не лише Presentation** — `StreakTracker`, `ReminderManager`, `ThemeManager` використовують Observation framework поза ViewModels. ~~Перевірити явно, чи Observation валідований для Swift SDK~~ → **перевірено 2026-10-02: `Observation` компілюється під Android.** Залишається окреме питання — як Compose отримує стан (див. Фазу 4).
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

## Фаза 1 — Пайплайн збірки: SPM → `jniLibs` → Gradle

Шлях обрано (див. Рекомендацію 7), тулчейн перевірено. Залишилось з'єднати їх у робочий цикл: щоб зміна у Swift-ядрі перекомпілювала `.so` і потрапляла в Android-модуль однією командою.

- [ ] Створити Gradle-модуль Android із папкою `src/main/jniLibs/arm64-v8a/`
- [ ] Зібрати `MeditateAndNoteCore` під `aarch64-unknown-linux-android28` і покласти `libMeditateAndNoteCore.so` у `jniLibs`
- [ ] **Автоматизувати крок зі Swift-білдом** — Gradle-задача або pre-build хук, інакше `lib*.so` розійдеться зі Swift-кодом (класичний спосіб зламати CI)
- [ ] Прогнати `jextract` для генерації Java-обгорток; перевірити, що Kotlin бачить виклик до `NoteStore`
- [ ] Найпростіший вертикальний зріз end-to-end: `NoteStore` (Swift) → Room-реалізація (Kotlin) → виклик із Compose-екрана
- [ ] Зафіксувати `minSdk` — нижня межа: SDK підтримує API 23+, але JNI-обгортки генеруються під `javaSourceLevel` 17+

**Результат фази:** зміна в Swift-домені → `./gradlew assembleDebug` → робочий Android-бинарник, без ручного копіювання `.so`.

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

> **Увага, JNI:** generic-метод `<T: Generable>` і макрос `@Generable` не мають шляху через JNI — generic-спеціалізація не перекладається в Java. Цей контракт **не має бути в публічному API ядра**; якщо Android їх потребує, доведеться заводити не-generic варіант (окремий метод під конкретний тип відповіді).

### 3.3 UI-адаптація під градуйовану доступність

- [ ] `AIWritingViewModel` реагує на `AICapabilityLevel`, а не на бінарний прапорець
- [ ] Визначити UX для кожного рівня: `.unavailable` → кнопка прихована, `.basicText` → "Help me write" доступний без гарантії формату, `.structuredOutput` → повний функціонал

---

## Фаза 4 — Presentation: Compose з нуля

Ніщо з SwiftUI не переноситься. Важливе уточнення після перевірки: **`@Observable` не є спільним контрактом стану** — Compose не спостерігає за Swift-об'єктами, навіть якщо сам `@Observable` компілюється під Android. Тому ViewModels **не** переносяться як-is: їхня логіка йшла в `@Observable`-властивостях, а Android потребує свого джерела стану.

- [ ] Обрати модель стану для Android: Kotlin `ViewModel` + `StateFlow` як дзеркало Swift-об'єкта, **чи** зробити Core джерелом істини й стримити стан через callback → `Flow`
- [ ] Спроєктувати Compose-еквіваленти екранів у тому ж порядку, що й existing Views/ (onboarding → meditation list → breathing UI → journal → insights)
- [ ] Breathing-анімації: `Canvas`/`TimelineView`/`trim(from:to:)` → Compose `Canvas` + `Animatable`/`rememberInfiniteTransition`
- [ ] Router: адаптувати кастомну Router-навігацію під Navigation Compose, зберігаючи ті самі destinations/deep links на рівні контракту
- [ ] Тема: `ThemeManager` живе у Swift-шарі й не портується — визначити, як Compose-тема синхронізується з нею (спільні токени, згенеровані з Swift, чи дублювання)

---

## Фаза 5 — Тести та валідація

- [ ] Портувати pure-engine тести (streak-логіка, insights) — мають пройти без змін, якщо Domain дійсно чистий
- [ ] Contract-тести для кожного нового `Store`/`Service` — та сама тестова сюїта, що й для CoreData/InMemory, прогнана проти Android-реалізацій
- [ ] Окремі device-матриця тести для AI-фіч: пристрій без AICore, пристрій з `.basicText`, пристрій з умовами "Gemini Intelligence" (12GB+ RAM, флагманський SoC)

---

## Ризики й відкриті питання

**Неперекладне вирішено.** `AsyncStream` і клоузури замінюються протоколом- підпискою — перевірено end-to-end (генерація Java + компіляція thunk під Android). Generic-методів у домені немає взагалі. Див. «Розв'язок, перевірений end-to-end».

**Головний ризик, що лишився — `jextract` мовчки пропускає непідтримувані методи.** `exit 0`, warning у лозі, методу немає. Помилка виявиться лише під час компіляції Kotlin. Тому перевірка логу `jextract` — обов'язковий крок CI, інакше «зелений» тулчейн систематично приховує діри в API.

**Другий — семантика потоку зміниться.** `DomainEventBus` зараз публікує «on the emitter's thread», а `AsyncStream` давав кожному споживачеві власний послідовний потік. Протокол- підписка не дає цього без додаткової роботи: щоб зберегти «послідовно, у порядку публікації» для `EventLoopCoordinator`, потрібна черга з `NSLock`/актором усередині шини. Без неї три споживачі оброблятимуть події в довільному порядку — зміниться поведінка, яку тримають 3 ViewModel-и.

**Третій — каскад `public` торкається 58 типів.** Працює, але великий diff у найбільшому шарі.

- **Нічого ще не запущено на пристрої** — усі висновки з виводу генератора; рантайм JNI (хто завершує `CompletableFuture`, з якого потоку приходить Kotlin-об'єкт) не перевірено
- **Жодного коду застосунку не скомпільовано** під Android — лише синтетичні проби; реальний `Models/`/`Services/` ще не пройшов перевірку
- **Core-пакет залежатиме від `SwiftJava`** — згенеровані thunk не компілюються без рантайм-бібліотеки `swift-java`. Це зовнішня залежність у Cargo-стилі SwiftPM, її треба зафіксувати версією
- **Розсинхрон `.so` зі Swift-кодом** — поки крок компіляції Swift не вбудований у Gradle, `lib*.so` буде розходитись із джерелом
- **Повний двоплатформний CI** — iOS-збірка й Android-збірка мають перевірятися разом, інакше Domain-зміни зламають одну платформу непомітно
- **`Compose` не бачить Swift-стан** — модель стану для Android ще не обрана
- ML Kit GenAI APIs у статусі Beta — можливі breaking changes до GA
- AICore не дає function calling / structured output "з коробки" — рівень 2 контракту на Android завжди буде емуляцією, не гарантією
- CoreData → Room міграція даних існуючих користувачів (якщо застосунок вже в проді) окремо не покрита цим планом — потребує стратегії міграції/експорту

---

## Що змінилося в цій редакції (2026-10-02)

Для чіткості — що було змінено відносно попередньої версії:

1. **Рекомендація 1 переписана.** Твердження «`@Observable` не компілюється під Android» було хибним — перевірено компілятором. З ним зник і аргумент за KMP.
2. **Рекомендація 7 переписана.** KMP відхилено, обрано Swift SDK for Android + Kotlin/Compose UI. Причина відхилення зафіксована, а не просто видалена.
3. **Додано «Перевірено експериментом»** — версії, робоча команда, три ловушки налаштування (API level у triple, `swiftly link` не перемикає shell, `swift-java` не збирається тулчейном 6.4).
4. **Розділ «Обмеження JNI-межі» переписано з здогадок на виміряні дані** (10 проб через `jextract --mode jni`): що перекладається, що ні, і чому це ламає `DomainEventBus` та `generateStructured<T>`.
5. **Фаза 1 змінила предмет:** не «вибір шляху», а пайплайн складання `SPM → .so → jniLibs → Gradle`.
6. **Фаза -1** тепер містить виміряні числа (54 файли / 5680 рядків у ядрі, 0 Apple-імпортів у `Models/`); проби `jextract` і пошук розв'язку позначено як виконані, додано пункти про каскад `public`, семантику черги та залежність від `SwiftJava`.
7. **Додано «Розв'язок, перевірений end-to-end»** — замість `AsyncStream`/клоузур протокол- підписка; доведено, що дженериків у домені немає, а type-erasure `any Encodable` не працює.
8. **Фаза 4** більше не припускає, що `@Observable` мапиться на Compose.
9. **Рекомендація 2 (AI) і Фази 0, 2, 3, 5** залишені без змін — експеримент їх не зачіпає.
10. **Tier 1 на пристрої.** Swift-екзешутер `NRuntime` на Samsung A24 (Android 16, API 36, arm64-v8a): UUID, String, struct round-trip, 1000 ітерацій — PASS. Рантайм Swift на Android підтверджено.
