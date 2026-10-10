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

    /**
     * Runs the full note blob round trip through Swift and fills [out] with
     * counts and flags. Same out-param rule as saveReminders: the buffer is
     * allocated by Kotlin because Kotlin cannot see Swift replace a reference.
     *
     * Swift side: KotlinNoteDataSource.swift
     */
    external fun noteProbe(out: LongArray)

    /**
     * Runs the streak snapshot round trip through Swift and fills [out] with
     * one flag per check. Same out-param rule as the probes above: the buffer is
     * allocated by Kotlin because Kotlin cannot see Swift replace a reference.
     *
     * Swift side: KotlinStreakActivityStore.swift
     */
    external fun streakProbe(out: LongArray)

    /**
     * Exercises the home-screen header read (`StreakHeaderSource_read`): Swift
     * writes a known snapshot, then fills the day flags the header thunk would.
     * Same out-param rule.
     *
     * Swift side: KotlinStreakActivityStore.swift
     */
    external fun streakHeaderProbe(out: LongArray)

    /**
     * Exercises the streak-detail read (`StreakDetailSource_read`): Swift writes
     * a known snapshot (with per-day times), then fills the timestamps and stats
     * the detail screen asks for. Same out-param rule.
     *
     * Swift side: KotlinStreakActivityStore.swift
     */
    external fun streakDetailProbe(out: LongArray)

    /**
     * Runs the meditation session round trip through Swift and fills [out] with
     * one flag per check. Same out-param rule as the probes above: the buffer is
     * allocated by Kotlin because Kotlin cannot see Swift replace a reference.
     *
     * Swift side: KotlinMeditationSessionStore.swift
     */
    external fun sessionProbe(out: LongArray)
}