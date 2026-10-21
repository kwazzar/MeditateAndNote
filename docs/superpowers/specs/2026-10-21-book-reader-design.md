# Book Reader Design — FB2 + EPUB + TXT (iOS + Android)

Date: 2026-10-21
Branch: `fb2-reading-view`
Status: approved (user, 2026-10-21)

## Intent

Full book-reader feature like the FB2Reader app: import FB2/EPUB/TXT e-books from the Files app, a library tab, and a paginated reader. Both iOS and Android, sharing the domain core through the existing JNI package.

Success criteria: user imports a book, opens it, reads with page turns, closes, reopens at saved position; works for all three formats.

## Scope

In v1: paginated reader (tap zones), saved reading position per book, font size, sepia/dark/light reader theme, progress %, cover images, library tab.

Out of v1 (add on demand): TOC, bookmarks, highlights→notes, in-book search, reading stats, inline images, reading-time streak integration.

## 1. Domain — `Packages/MeditateAndNoteCore`

New types (no CoreData/SwiftUI/UIKit imports):

- `Book` — entity: `id`, `title`, `author`, `format` (`fb2`/`epub`/`txt`), `addedAt`, `lastOpenedAt`
- `BookChapter` / `BookBlock` — parsed content: chapters → text blocks (headings + paragraphs). Only cover image extracted; inline images skipped
- `BookContent` — `[BookChapter]`, produced by parsers
- `ReadingPosition` — value object: chapter index + block index + character offset; clamping lives in the type
- `BookStore` protocol — `fetchAll`/`fetch`/`save`/`delete` for `Book` + `ReadingPosition` + cover data (per-domain store convention, no generic repository)
- `TextMeasurer` protocol — platform-injected font metrics (iOS: `UIFont`, Android: `android.graphics.Paint`)
- `PaginationEngine` — greedy text layout: `BookContent` + `TextMeasurer` + page size → pages with position mapping. Re-pagination on font/rotation change resolves position by character offset, never page number. Pure and unit-testable, follows `MeditationSessionEngine` pattern

Parsers (in Core, platform-neutral):

- `FB2Parser` — Foundation `XMLParser`
- `TXTParser` — paragraph splitting
- `EPUBParser` — takes a file-access closure `(String) -> Data?` so ZIP handling stays in the platform layer; Core stays dependency-free

Domain invariants (position clamping, re-pagination stability) live in `ReadingPosition` / `PaginationEngine`, not ViewModels.

## 2. Infrastructure

iOS:

- `CoreDataBookStore` — `NSManagedObject` for book + position + cover data; mapping (`.toBook()`/`.apply()`) inside the store
- `InMemoryBookStore` — tests/previews
- Book files copied to `Application Support/Books/<uuid>.<ext>` at import; file name stored in the CoreData record
- New dependency: **ZIPFoundation** (iOS app target only, for EPUB ZIP containers). Only external dep beyond RevenueCat
- Cover extraction: FB2 `<coverpage>` base64, EPUB cover from OPF metadata, TXT placeholder

Android mirror (per ANDROID_PORT_PLAN 2.x): `domain/` reuses Core via JNI; `data/` store impl; probes `BookStoreProbe.kt`, `PaginationEngineProbe.kt`.

## 3. Application

- `BookManager` split into `BookProvidable` (read library) / `BookManageable` (import, delete, save position)
- Typed errors: `BookImportError`, `BookOperationError`
- Import: security-scoped access → copy → parse metadata → persist. Full parse lazily on first open.

## 4. Presentation (iOS)

- `TabDestination.reading` → `LibraryView`: cover grid, `fileImporter` import, progress % badge
- Reader as `FullScreenDestination.reader(bookId:)`: paged, tap zones (left/right = turn, center = settings), pagination on background task, re-paginate on font/orientation change, position saved on page turn + background
- `ReaderSettingsSheet`: font size, reader theme (sepia/dark/light — separate from app `ThemeManager`)
- `AppContainer` factories: `makeLibraryViewModel()`, `makeReaderViewModel(bookId:)`
- Router: new destinations; `.readingView` placeholder push removed (MeditationCompletionView fills the post-meditation slot)

## 5. Android (Compose, M3)

`LibraryScreen` + `ReaderScreen` in `presentation/`, nav routes; same Core engine/parsers via JNI; `TextMeasurer` impl with `Paint.measureText`. Ported after iOS green, per port-ios-screen-to-android skill.

## 6. Testing

- Core: pagination engine (wrap, overflow, position round-trip, re-pagination stability), parser fixtures (FB2, EPUB, TXT edge cases: empty, huge single paragraph)
- iOS: store round-trip, import flow
- Android: JNI probes drive the same tests
