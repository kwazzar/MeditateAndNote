package com.mn.android

/**
 * Entry point for the reverse JNI probe. Lives in its own class because the
 * JNI symbol name is derived from it: `Java_com_mn_android_NativeProbe_*`
 * matches `com.mn.android.NativeProbe`, and a mismatch here fails at runtime
 * with "No implementation found", not at compile time.
 */
object NativeProbe {

    init {
        // The generated classes load the library in their own static
        // initializers; doing it here keeps the probe independent of whichever
        // class happens to be touched first.
        Class.forName("com.mn.core.AIDraftMetric")
    }

    /**
     * Implemented in ReverseJniProbeEntry.swift. Returns 1 if Swift reached
     * Kotlin's `ping()` and got the expected string back, -1 if the call threw.
     */
    external fun reverseJNI(): Long

    /**
     * Saves through the Swift store, then reads back and fills [out].
     *
     * The result is written into an array Kotlin allocated rather than returned:
     * Swift cannot swap the reference Kotlin passed, so the buffer has to belong
     * to Kotlin. Swift side: KotlinReminderSettingsStore.swift
     */
    external fun saveReminders(
        enabled: Boolean,
        hour: Int,
        minute: Int,
        weekdays: LongArray,
        out: LongArray,
    )

    /** Reads through the Swift store. Same [out] shape as saveReminders. */
    external fun loadReminders(out: LongArray)
}