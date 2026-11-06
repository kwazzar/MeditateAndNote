package com.mn.android.application.container

import android.content.Context
import androidx.lifecycle.SavedStateHandle
import com.mn.android.data.NoteEditorSource
import com.mn.android.data.NoteInsightsSource
import com.mn.android.data.NoteMenuSource
import com.mn.android.data.SessionRecorder
import com.mn.android.data.aidraft.JniAIDraftRepository
import com.mn.android.data.book.JniBookmarkRepository
import com.mn.android.data.book.JniBookRepository
import com.mn.android.data.meditation.JniMeditationRepository
import com.mn.android.data.note.JniNoteInsightsRepository
import com.mn.android.data.note.JniNoteRepository
import com.mn.android.data.reader.AndroidTextMeasurer
import com.mn.android.data.reminder.JniReminderSettingsStore
import com.mn.android.data.streak.JniStreakRepository
import com.mn.android.data.AIDraftSettingsStore
import com.mn.android.domain.book.BookId
import com.mn.android.domain.book.BookRepository
import com.mn.android.domain.book.BookmarkRepository
import com.mn.android.domain.aidraft.AIDraftMetricRecorder
import com.mn.android.domain.aidraft.AIDraftRepository
import com.mn.android.domain.aidraft.AIDraftSettings
import com.mn.android.domain.events.DomainEventBus
import com.mn.android.domain.insights.NoteInsightsRepository
import com.mn.android.domain.meditation.MeditationRepository
import com.mn.android.domain.meditation.MeditationSelectionStore
import com.mn.android.domain.meditation.SoundPlayer
import com.mn.android.domain.note.NoteId
import com.mn.android.domain.note.NoteRepository
import com.mn.android.domain.reader.ReaderSettings
import com.mn.android.domain.settings.AnimationStyleStore
import com.mn.android.domain.settings.ReminderScheduler
import com.mn.android.domain.settings.ReminderSettingsStore
import com.mn.android.domain.settings.SoundVolumeStore
import com.mn.android.domain.reader.TextMeasurer
import com.mn.android.domain.streak.StreakRepository
import com.mn.android.domain.theme.ThemeSelectionStore
import com.mn.android.infrastructure.persistence.local.ai.AIDraftMetrics
import com.mn.android.infrastructure.persistence.local.meditation.MeditationCatalog
import com.mn.android.infrastructure.persistence.local.meditation.MeditationSelection
import com.mn.android.infrastructure.persistence.local.settings.AnimationSettings
import com.mn.android.infrastructure.persistence.local.settings.MnThemeStore
import com.mn.android.infrastructure.persistence.local.settings.SoundSettings
import com.mn.android.infrastructure.persistence.local.reader.ReaderSettingsImpl
import com.mn.android.infrastructure.platform.notifications.AndroidReminderScheduler
import com.mn.android.infrastructure.platform.sound.SoundPlayerImpl
import com.mn.android.presentation.meditate.viewmodel.BreathingSessionViewModel
import com.mn.android.presentation.meditate.viewmodel.MeditateSelectViewModel
import com.mn.android.presentation.notes.viewmodel.NoteEditorViewModel
import com.mn.android.presentation.notes.viewmodel.NoteInsightsViewModel
import com.mn.android.presentation.reading.viewmodel.LibraryViewModel
import com.mn.android.presentation.reading.viewmodel.ReaderViewModel
import com.mn.android.presentation.settings.viewmodel.SettingsViewModel
import com.mn.android.presentation.notes.viewmodel.NoteMenuViewModel
import kotlinx.coroutines.Dispatchers

/**
 * The Android DI root. Factory methods, not a registration container: each
 * `make<X>ViewModel()` names the dependencies its ViewModel needs.
 */
object AppContainer {

    /** The saved-state key of the editor's note id. */
    private const val KEY_EDITOR_NOTE_ID = "noteEditorNoteId"

    /**
     * Work that must outlive the screen that started it: the reader saves the
     * reading position from its dispose hook, where no coroutine scope is left.
     */
    val applicationScope: kotlinx.coroutines.CoroutineScope =
        kotlinx.coroutines.CoroutineScope(
            kotlinx.coroutines.SupervisorJob() + kotlinx.coroutines.Dispatchers.Default
        )

    @Volatile
    private var noteRepository: NoteRepository? = null

    @Volatile
    private var meditationRepository: MeditationRepository? = null

    @Volatile
    private var soundPlayer: SoundPlayer? = null

    @Volatile
    private var streakRepository: StreakRepository? = null

    @Volatile
    private var bookRepository: BookRepository? = null

    @Volatile
    private var bookmarkRepository: BookmarkRepository? = null

    @Volatile
    private var readerSettings: ReaderSettings? = null

    @Volatile
    private var textMeasurer: TextMeasurer? = null

    @Volatile
    private var aiDraftRepository: AIDraftRepository? = null


    fun getNoteRepository(context: Context): NoteRepository =
        noteRepository ?: synchronized(this) {
            noteRepository ?: JniNoteRepository(
                editor = NoteEditorSource,
                menu = NoteMenuSource
            ).also { noteRepository = it }
        }

    fun getMeditationRepository(context: Context): MeditationRepository =
        meditationRepository ?: synchronized(this) {
            meditationRepository ?: JniMeditationRepository(
                catalogSource = MeditationCatalog,
                recorder = SessionRecorder
            ).also { meditationRepository = it }
        }

    fun getSoundPlayer(context: Context): SoundPlayer =
        soundPlayer ?: synchronized(this) {
            soundPlayer ?: SoundPlayerImpl.also { sp ->
                sp.configure(context)
                soundPlayer = sp
            }
        }

    /** The streak snapshot + insights. Stateless, so it needs no context. */
    fun getStreakRepository(): StreakRepository =
        streakRepository ?: synchronized(this) {
            streakRepository ?: JniStreakRepository().also { streakRepository = it }
        }

    /** The library and the reading session. */
    fun getBookRepository(context: Context): BookRepository =
        bookRepository ?: synchronized(this) {
            bookRepository ?: JniBookRepository(cacheDir = context.cacheDir).also { bookRepository = it }
        }

    /** The reader's marks and the table of contents. */
    fun getBookmarkRepository(): BookmarkRepository =
        bookmarkRepository ?: synchronized(this) {
            bookmarkRepository ?: JniBookmarkRepository().also { bookmarkRepository = it }
        }

    /** The reader's appearance preferences. */
    fun getReaderSettings(context: Context): ReaderSettings {
        ReaderSettingsImpl.configure(context)
        return ReaderSettingsImpl
    }

    /** The platform text measurement the pagination engine and the reader share. */
    fun getTextMeasurer(): TextMeasurer =
        textMeasurer ?: synchronized(this) {
            textMeasurer ?: AndroidTextMeasurer().also { textMeasurer = it }
        }

    /**
     * The AI draft path. The session state machine and the free-quota rule
     * live in Core; Kotlin only carries the commands and the answers.
     */
    fun getAIDraftRepository(): AIDraftRepository =
        aiDraftRepository ?: synchronized(this) {
            aiDraftRepository ?: JniAIDraftRepository().also { aiDraftRepository = it }
        }

    /** Where the draft telemetry lands. */
    fun getAIDraftMetricRecorder(context: Context): AIDraftMetricRecorder {
        AIDraftMetrics.configure(context)
        return AIDraftMetrics
    }

    /** The reminder settings: when the daily reminder fires. */
    fun getReminderSettings(context: Context): ReminderSettingsStore {
        return JniReminderSettingsStore(context)
    }

    /** Arms the next reminder dates. */
    fun getReminderScheduler(context: Context): ReminderScheduler {
        AndroidReminderScheduler.configure(context)
        return AndroidReminderScheduler
    }

    /** The session sound volume. */
    fun getSoundVolume(context: Context): SoundVolumeStore {
        SoundSettings.configure(context)
        return SoundSettings
    }

    /** How the breathing animation moves. */
    fun getAnimationStyle(context: Context): AnimationStyleStore {
        AnimationSettings.configure(context)
        return AnimationSettings
    }

    /** The theme the user picked. */
    fun getThemeSelection(context: Context): ThemeSelectionStore {
        MnThemeStore.configure(context)
        return MnThemeStore
    }

    /** The settings screen: reminder, animation, sound, theme. */
    fun makeSettingsViewModel(context: Context): SettingsViewModel =
        SettingsViewModel(
            reminderStore = getReminderSettings(context),
            reminderScheduler = getReminderScheduler(context),
            soundVolume = getSoundVolume(context),
            animationStyleStore = getAnimationStyle(context),
            themeStore = getThemeSelection(context),
        )

    /** Where the AI draft provider lives: the endpoint, the model and the key. */
    fun getAIDraftSettings(context: Context): AIDraftSettings {
        AIDraftSettingsStore.configure(context)
        return AIDraftSettingsStore
    }

    /** The last-picked meditation: a per-platform preference behind an interface. */
    fun getMeditationSelection(context: Context): MeditationSelectionStore {
        MeditationSelection.configure(context)
        return MeditationSelection
    }

    fun makeBreathingSessionViewModel(
        context: Context,
        savedStateHandle: SavedStateHandle
    ): BreathingSessionViewModel = BreathingSessionViewModel(
        savedStateHandle = savedStateHandle,
        meditationRepository = getMeditationRepository(context),
        soundPlayer = getSoundPlayer(context),
        selection = getMeditationSelection(context),
    )

    fun makeMeditateSelectViewModel(context: Context): MeditateSelectViewModel = MeditateSelectViewModel(
        meditationRepository = getMeditationRepository(context)
    )

    /**
     * The note editor.
     *
     * A new note's id is generated up front and kept in the saved state, so
     * the note survives the process being killed after the first autosave.
     */
    fun makeNoteEditorViewModel(
        context: Context,
        savedStateHandle: SavedStateHandle,
        noteId: String?,
    ): NoteEditorViewModel {
        val notes = getNoteRepository(context)
        val id = noteId?.let { NoteId(it) }
            ?: savedStateHandle.get<String>(KEY_EDITOR_NOTE_ID)?.let { NoteId(it) }
            ?: notes.newId().also { savedStateHandle[KEY_EDITOR_NOTE_ID] = it.value }
        return NoteEditorViewModel(
            noteId = id,
            isNew = noteId == null,
            notes = notes,
            drafts = getAIDraftRepository(),
            draftSettings = getAIDraftSettings(context),
            metricRecorder = getAIDraftMetricRecorder(context),
            backgroundScope = applicationScope,
        )
    }

    /** The notes list. */
    fun makeNoteMenuViewModel(context: Context): NoteMenuViewModel = NoteMenuViewModel(
        notes = getNoteRepository(context),
    )

    /** The reader: the book, the page being read, the marks. */
    fun makeReaderViewModel(context: Context, bookId: String): ReaderViewModel =
        ReaderViewModel(
            bookId = BookId(bookId),
            books = getBookRepository(context),
            bookmarks = getBookmarkRepository(),
            backgroundScope = applicationScope,
        )

    /** The library screen: the books, the covers, the import and the delete. */
    fun makeLibraryViewModel(context: Context): LibraryViewModel =
        LibraryViewModel(repository = getBookRepository(context))

    /** The note-insights reads: the heuristic pass, the stored pass, an analysis. */
    fun getNoteInsightsRepository(): NoteInsightsRepository = JniNoteInsightsRepository()

    fun makeNoteInsightsViewModel(): NoteInsightsViewModel = NoteInsightsViewModel(
        repository = getNoteInsightsRepository(),
        ioDispatcher = Dispatchers.IO,
        events = DomainEventBus.events
    )
}
