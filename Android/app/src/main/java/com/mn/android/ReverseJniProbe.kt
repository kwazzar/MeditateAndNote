package com.mn.android

/**
 * Probe for the reverse JNI direction: can Swift call *into* Kotlin?
 *
 * Everything proven so far is Kotlin calling Swift (Java -> JNI -> Swift), which
 * is the direction jextract generates. Phase 2 option B needs the other one:
 * Swift domain code driving a Kotlin `Room` implementation of a Swift protocol.
 * Nobody has checked whether that works, so this is the smallest thing that can
 * fail: one static method, no arguments, returning a String.
 *
 * If Swift can read this back, option B is viable. If it cannot, Phase 2 has to
 * be option A (Kotlin owns persistence, Swift is called one-way) and this file
 * should be deleted rather than kept.
 */
object ReverseJniProbe {

    /**
     * Distinctive enough that finding it in the output proves Swift received
     * *this* string and did not invent one or read back its own argument.
     */
    const val PONG = "pong-from-kotlin-8f3a"

    @JvmStatic
    fun ping(): String = PONG

    /**
     * Proves arguments survive the trip too, not just a zero-arg call.
     */
    @JvmStatic
    fun echo(value: Long): Long = value * 2 + 1
}