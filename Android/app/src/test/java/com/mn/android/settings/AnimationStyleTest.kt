package com.mn.android.settings

import com.mn.android.domain.settings.AnimationStyle
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AnimationStyleTest {

    @Test
    fun of_knownRawValue_returnsTheStyle() {
        assertEquals(AnimationStyle.RINGS, AnimationStyle.of("rings"))
        assertEquals(AnimationStyle.PATH, AnimationStyle.of("path"))
    }

    @Test
    fun of_unknownRawValue_fallsBackToTheFreeDefault() {
        assertEquals(AnimationStyle.PATH, AnimationStyle.of("bogus"))
        assertEquals(AnimationStyle.PATH, AnimationStyle.of(null))
    }

    @Test
    fun isPremium_onlyRingsNeedsTheEntitlement() {
        assertTrue(AnimationStyle.RINGS.isPremium)
        assertFalse(AnimationStyle.PATH.isPremium)
    }
}
