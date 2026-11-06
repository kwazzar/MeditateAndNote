package com.mn.android.data.streak

import com.mn.android.data.StreakDetailSource
import com.mn.android.data.StreakHeaderSource
import com.mn.android.data.StreakInsightsSource
import com.mn.android.domain.streak.Bundle
import com.mn.android.domain.streak.Detail
import com.mn.android.domain.streak.Header
import com.mn.android.domain.streak.StreakRepository
import java.time.LocalDate

/**
 * Adapts the three JNI streak bridges to [StreakRepository].
 *
 * The bridges keep their own names because the Swift side registers the JNI
 * symbols under them (`Java_com_mn_android_data_StreakHeaderSource_read`).
 */
class JniStreakRepository(
    private val headerSource: StreakHeaderSource = StreakHeaderSource,
    private val detailSource: StreakDetailSource = StreakDetailSource,
    private val insightsSource: StreakInsightsSource = StreakInsightsSource,
) : StreakRepository {

    override fun readHeader(): Header = headerSource.readHeader()

    override fun readDetail(anchor: LocalDate): Detail = detailSource.readDetail(anchor)

    override fun readInsights(range: String): Bundle = insightsSource.load(range)
}
