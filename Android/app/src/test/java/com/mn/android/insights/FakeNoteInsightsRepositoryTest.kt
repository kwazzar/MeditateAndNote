package com.mn.android.insights

import com.mn.android.domain.insights.NoteInsightsRepository

/** The contract, run against the in-memory insights. */
class FakeNoteInsightsRepositoryTest : NoteInsightsRepositoryContract() {
    override fun createRepo(): NoteInsightsRepository = FakeNoteInsightsRepository()
}
