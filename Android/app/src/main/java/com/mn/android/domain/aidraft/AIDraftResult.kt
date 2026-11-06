package com.mn.android.domain.aidraft

/** What a draft command answered: the new session, or the error. */
data class AIDraftResult(
    val session: AIDraftSession?,
    val metric: AIDraftMetric?,
    val error: AIDraftError?,
) {
    val ok: Boolean get() = error == null
}
