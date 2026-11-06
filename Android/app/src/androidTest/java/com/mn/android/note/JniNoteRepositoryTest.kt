package com.mn.android.note

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.mn.android.data.NoteBlobStore
import com.mn.android.data.NoteEditorSource
import com.mn.android.data.NoteMenuSource
import com.mn.android.data.StreakSnapshotStore
import com.mn.android.data.note.JniNoteRepository
import org.junit.Before
import org.junit.runner.RunWith

/**
 * The JNI note store against a real device. The default id has to be a UUID
 * string: the Swift side parses it with `UUID(uuidString:)` and silently
 * refuses to save anything else.
 */
@RunWith(AndroidJUnit4::class)
class JniNoteRepositoryTest : NoteRepositoryContract() {

    @Before
    fun configureStores() {
        // The blob store opens its SQLite file on configure; without it every
        // save fails inside the Swift bridge, which reports an empty title.
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        NoteBlobStore.configure(context)
        StreakSnapshotStore.configure(context)
    }

    override fun createRepo() = JniNoteRepository(
        editor = NoteEditorSource,
        menu = NoteMenuSource,
    )
}
