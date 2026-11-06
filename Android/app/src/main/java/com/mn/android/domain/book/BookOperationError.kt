package com.mn.android.domain.book

/** What can go wrong on the book path. */
sealed class BookOperationError(cause: Throwable) : Exception(cause) {
    class ImportFailed(cause: Throwable) : BookOperationError(cause)
    class DeleteFailed(cause: Throwable) : BookOperationError(cause)
    class LoadFailed(cause: Throwable) : BookOperationError(cause)
    class SaveFailed(cause: Throwable) : BookOperationError(cause)
    class OpenFailed(cause: Throwable) : BookOperationError(cause)
}
