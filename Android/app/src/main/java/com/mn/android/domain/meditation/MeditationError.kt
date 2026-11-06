package com.mn.android.domain.meditation

sealed class MeditationError(cause: Throwable? = null) : Exception(cause) {
    class RecordFailed(cause: Throwable?) : MeditationError(cause)
}
