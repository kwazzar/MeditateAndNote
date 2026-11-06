package com.mn.android.domain.meditation

data class CompletedSession(
    val meditationId: MeditationId,
    val durationSeconds: Int,
    val dateMillis: Long,
    val tzOffsetMinutes: Int
)