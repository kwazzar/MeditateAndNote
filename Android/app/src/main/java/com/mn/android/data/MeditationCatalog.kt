package com.mn.android.data

import android.content.Context
import android.content.SharedPreferences
import com.mn.core.SampleMeditationService
import org.swift.swiftkit.core.SwiftMemoryManagement

/**
 * UI-side copy of Core's `Meditation`. Compose never holds the jextract
 * wrappers: every getter is a JNI round trip, and the wrappers are arena-bound
 * memory addresses, so the catalog is flattened to strings once on load.
 */
data class MeditationUi(
    val id: String,
    val title: String,
    /** `meditation.breathingStyle.pattern.name`, e.g. "4-7-8". */
    val patternName: String,
    val description: String?,
    /** `MeditationCategory` raw value: mindfulness/breathing/sleep/focus/relaxation. */
    val category: String,
    /** `Meditation.breathingStyle.rawValue`: `4-7-8`, `Box`, `4-8`, `Custom`. */
    val breathingStyleRawValue: String,
)

/**
 * Reads the meditation catalog through the generated Swift bindings — the
 * catalog is domain data (six entries authored in `SampleMeditationService`),
 * so duplicating it in Kotlin would let the two copies drift.
 *
 * Throwing, not swallowing: an empty catalog from a failed JNI call would render
 * as the legitimate "No Meditations Available" empty state, which is exactly the
 * kind of silent green the port plan warns about. The screen shows the error.
 */
object MeditationCatalog {

    fun load(): List<MeditationUi> {
        val arena = SwiftMemoryManagement.DEFAULT_SWIFT_JAVA_AUTO_ARENA
        return SampleMeditationService.init(arena)
            .getMeditations(arena)
            .map { meditation ->
                MeditationUi(
                    id = meditation.getId(arena).getRawValue(),
                    title = meditation.getTitle(arena).getRawValue(),
                    patternName = meditation.getBreathingStyle(arena).getPattern(arena).getName(),
                    description = meditation.description.orElse(null),
                    category = meditation.getCategory(arena).getRawValue(),
                    breathingStyleRawValue = meditation.getBreathingStyle(arena).getRawValue(),
                )
            }
    }
}

/**
 * Android side of Core's `MeditationSelectionStore`
 * (`MeditateAndNoteCore/Meditation/MeditationService.swift`): one optional
 * string under the same key, so both platforms read the same name side by side
 * while the storage stays per-platform (SharedPreferences here, UserDefaults
 * there) — the `OnboardingStore` arrangement. Not a JNI round trip for the same
 * reason: a last-picked id carries no invariant the domain can get wrong.
 */
object MeditationSelection {

    private const val PREFS = "meditation"
    private const val KEY = "lastSelectedMeditationId"

    @Volatile
    private var prefs: SharedPreferences? = null

    fun configure(context: Context) {
        if (prefs == null) {
            synchronized(this) {
                if (prefs == null) {
                    prefs = context.applicationContext
                        .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                }
            }
        }
    }

    var lastSelectedId: String?
        get() = prefs?.getString(KEY, null)
        set(value) {
            prefs?.edit()?.putString(KEY, value)?.apply()
        }
}
