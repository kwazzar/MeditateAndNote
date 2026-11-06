package com.mn.android.domain.aidraft

/**
 * What can go wrong on the draft path.
 *
 * `Failed` carries the bridge's own name for the failure: the domain decides
 * what the UI shows, the bridge decides what happened.
 */
sealed class AIDraftError(cause: Throwable? = null) : Exception(cause) {
    /** The user has not pointed the app at a provider. */
    class NoProvider(cause: Throwable? = null) : AIDraftError(cause)

    /** The free allowance is used up; premium unlocks more. */
    class FreeQuotaExhausted(cause: Throwable? = null) : AIDraftError(cause)

    /** Any other failure, named by the bridge's raw value. */
    class Failed(val kind: String, cause: Throwable? = null) : AIDraftError(cause)
}
