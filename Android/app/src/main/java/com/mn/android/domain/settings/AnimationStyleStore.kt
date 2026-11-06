package com.mn.android.domain.settings

/**
 * How the breathing animation moves.
 *
 * The raw values are Core's (`BreathingAnimationStyle`), so the storage keeps
 * them readable by the other platform.
 */
enum class AnimationStyle(val raw: String) {
    RINGS("rings"),
    PATH("path"),
    ;

    /**
     * `BreathingAnimationStyle.isPremium` on iOS: `path` is the free default,
     * `rings` needs the `pro` entitlement. The rule lives in Core, but
     * jextract does not generate a getter for a computed property of an enum,
     * so it is mirrored here.
     */
    val isPremium: Boolean get() = this == RINGS

    companion object {
        fun of(raw: String?): AnimationStyle =
            entries.firstOrNull { it.raw == raw } ?: PATH
    }
}

/** Where the animation style lives. */
interface AnimationStyleStore {
    var style: AnimationStyle
}
