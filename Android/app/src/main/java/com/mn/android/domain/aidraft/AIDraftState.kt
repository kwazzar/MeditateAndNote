package com.mn.android.domain.aidraft

/** The state the session is in. The bridge owns the transition rules. */
enum class AIDraftState {
    IDLE,
    GENERATING,
    READY,
    CANCELLED,
    FAILED,
    ;

    companion object {
        /** The bridge's own name for the state; an unknown one means idle. */
        fun of(raw: String): AIDraftState = when (raw) {
            "generating" -> GENERATING
            "ready" -> READY
            "cancelled" -> CANCELLED
            "failed" -> FAILED
            else -> IDLE
        }
    }
}
