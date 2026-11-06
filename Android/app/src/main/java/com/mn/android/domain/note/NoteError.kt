package com.mn.android.domain.note

sealed class NoteError(cause: Throwable? = null) : Exception(cause) {
    class SaveFailed(cause: Throwable?) : NoteError(cause)
    class DeleteFailed(cause: Throwable?) : NoteError(cause)
    class LoadFailed(cause: Throwable?) : NoteError(cause)
}