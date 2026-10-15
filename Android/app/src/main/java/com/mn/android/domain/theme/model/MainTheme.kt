package com.mn.android.domain.theme.model

/**
 * Compose mirror of `MainTheme` in
 * `MeditateAndNote/Views/Theme/MainTheme.swift` — the *metadata* half only
 * (identity, storage key, icon, darkness). The colour table lives in
 * presentation (`MainTheme.colors`), because it is Compose `Color` values and
 * this enum must stay free of Android/Compose so persistence can depend on it.
 *
 * The Swift side is the source of truth: five themes. A theme picked on one
 * platform renders the same way on the other.
 */
enum class MainTheme(
    val storageKey: String,
    val displayName: String,
    /** SF Symbol name on iOS; the Compose picker maps it to a Material icon. */
    val systemIconName: String,
) {
    LIQUID_GLASS("liquidGlass", "Liquid Glass", "drop.fill"),
    BREATHING("breathing", "Breathing", "wind"),
    SOFT_DAWN("softDawn", "Soft Dawn", "sunrise.fill"),
    DARK_ZEN("darkZen", "Dark Zen", "moon.stars.fill"),
    OBSIDIAN("obsidian", "Obsidian", "flame.fill"),
    ;

    val isDark: Boolean get() = this == DARK_ZEN || this == OBSIDIAN

    companion object {
        /** `ThemeManager` key is `selectedMainTheme`; unknown values fall back to darkZen. */
        fun fromStorageKey(key: String?): MainTheme =
            entries.firstOrNull { it.storageKey == key } ?: DARK_ZEN
    }
}
