package com.mn.android.infrastructure.persistence.local.meditation

import com.mn.android.domain.meditation.model.MeditationUi
import com.mn.core.SampleMeditationService
import org.swift.swiftkit.core.SwiftMemoryManagement

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
