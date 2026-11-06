package com.mn.android.domain.streak

import java.time.LocalDate

/**
 * Reads the streak snapshot and the insight bundle.
 *
 * The insight math stays in Swift Core — Kotlin only decodes what the bridge
 * returns. The reads are snapshots: the screens re-read them on the domain
 * events, so there is nothing to observe.
 */
interface StreakRepository {
    /** The current streak and the last seven days' flags, oldest first. */
    fun readHeader(): Header

    /** The stats header plus the calendar grid of [anchor]'s month. */
    fun readDetail(anchor: LocalDate = LocalDate.now()): Detail

    /** The insights for a range ("last7", "last30", "all"). */
    fun readInsights(range: String): Bundle
}
