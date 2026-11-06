package com.mn.android.insights

import com.mn.android.domain.insights.NoteInsight
import com.mn.android.domain.insights.NoteInsightsRepository
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The shape every NoteInsightsRepository implementation has to keep, whatever
 * backs it. The assertions are on the structure the section renders, not on
 * the words a specific analyzer happens to produce.
 */
abstract class NoteInsightsRepositoryContract {
    protected abstract fun createRepo(): NoteInsightsRepository

    @Test fun heuristicPassAnswersWithInsights() {
        val insights = createRepo().heuristic()
        assertNotNull(insights)
        assertTrue(insights.all { it.id.isNotEmpty() })
    }

    @Test fun storedPassAnswersWithInsights() {
        val insights = createRepo().stored()
        assertNotNull(insights)
        assertTrue(insights.all { it.id.isNotEmpty() })
    }

    @Test fun analysisAnswersWithAnEnvelope() {
        val analysis = createRepo().analyze()
        assertNotNull(analysis)
        // A failed pass carries an error and no insights; a successful one the
        // other way round. Both are data, neither throws.
        if (analysis.error != null) assertTrue(analysis.insights.isEmpty())
        else assertNotNull(analysis.source)
    }
}
