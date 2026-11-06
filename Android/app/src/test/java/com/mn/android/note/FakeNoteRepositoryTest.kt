package com.mn.android.note

class FakeNoteRepositoryTest : NoteRepositoryContract() {
    override fun createRepo() = FakeNoteRepository()
}