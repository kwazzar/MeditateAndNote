package com.mn.android.domain.meditation

/**
 * The meditation the user last picked. A UI preference, not domain data —
 * but it still has to reach the ViewModel through an interface, so the
 * ViewModel does not name the storage.
 */
interface MeditationSelectionStore {
    var lastSelectedId: String?
}
