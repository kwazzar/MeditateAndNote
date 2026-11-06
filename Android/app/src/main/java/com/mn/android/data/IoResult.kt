package com.mn.android.data

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Runs a blocking JNI call off the main thread and wraps the failure in a
 * domain error. `CancellationException` is rethrown: swallowing it would make
 * a cancelled coroutine look like a failed call.
 */
suspend fun <T> ioResult(
    wrap: (Throwable) -> Exception,
    block: () -> T
): Result<T> = withContext(Dispatchers.IO) {
    try { Result.success(block()) }
    catch (e: CancellationException) { throw e }
    catch (e: Throwable) { Result.failure(wrap(e)) }
}

/**
 * The same, for a read that has nothing to wrap: the caller gets the value or
 * the exception, off the main thread.
 */
suspend fun <T> io(block: () -> T): T = withContext(Dispatchers.IO) { block() }
