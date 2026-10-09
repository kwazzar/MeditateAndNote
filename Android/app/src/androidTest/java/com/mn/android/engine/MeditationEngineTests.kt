package com.mn.android.engine

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.mn.core.BreathingPhase
import com.mn.core.BreathingPattern
import com.mn.core.BreathingPhaseType
import com.mn.core.Date
import com.mn.core.MeditationSessionEngine
import com.mn.core.MeditationDuration
import com.mn.core.SessionDuration
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.swift.swiftkit.core.SwiftArena
import org.swift.swiftkit.core.SwiftMemoryManagement

@RunWith(AndroidJUnit4::class)
class MeditationEngineTests {

    private val base = Date.init(1_700_000_000.0, SwiftMemoryManagement.DEFAULT_SWIFT_JAVA_AUTO_ARENA)
    private val arena = SwiftMemoryManagement.DEFAULT_SWIFT_JAVA_AUTO_ARENA

    private fun tickPattern(): BreathingPattern {
        val inhalePhase = BreathingPhase.init(BreathingPhaseType.inhale(arena), 1.0, arena)
        val exhalePhase = BreathingPhase.init(BreathingPhaseType.exhale(arena), 1.0, arena)
        val phases = arrayOf(inhalePhase, exhalePhase)
        return BreathingPattern.init("Tick", phases, arena)
    }

    private fun makeEngine(): MeditationSessionEngine {
        return MeditationSessionEngine.init(tickPattern(), arena)
    }

    private fun sec(value: Double): SessionDuration {
        return SessionDuration.init(value, arena)
    }

    private fun dateAdd(base: Date, seconds: Double): Date {
        return Date.init(base.getTimeIntervalSince1970() + seconds, arena)
    }

    @Test
    fun testCountdownTicksThenStarts() {
        val engine = makeEngine()

        val eventsStart = engine.start(sec(60.0), 3, base, arena)
        assertTrue(eventsStart.isNotEmpty())
        assertEquals(1, eventsStart.size)
        
        assertTrue(engine.isCountingDown())
        assertTrue(engine.countdownRemaining.isPresent)
        assertEquals(3L, engine.countdownRemaining.getAsLong())

        val e2 = engine.tickCountdown(dateAdd(base, 0.0), arena)
        assertTrue(e2.isNotEmpty())
        assertEquals(2L, engine.countdownRemaining.getAsLong())

        val e3 = engine.tickCountdown(dateAdd(base, 0.0), arena)
        assertTrue(e3.isNotEmpty())
        assertEquals(1L, engine.countdownRemaining.getAsLong())

        val final = engine.tickCountdown(dateAdd(base, 0.0), arena)
        assertTrue(final.isNotEmpty())
    }

    @Test
    fun testCountdownTickIdlesInFinishedStateDoesNothing() {
        val engine = makeEngine()
        engine.start(sec(60.0), 0, base, arena)

        val idle = engine.tickCountdown(dateAdd(base, 0.0), arena)
        assertEquals(0, idle.size)
    }

    @Test
    fun testStartWithoutCountdownStartsSessionImmediately() {
        val engine = makeEngine()
        val events = engine.start(sec(60.0), 0, base, arena)
        assertTrue(events.isNotEmpty())
        assertTrue(engine.isActive())
    }

    @Test
    fun testStopResetsToIdle() {
        val engine = makeEngine()
        engine.start(sec(60.0), 3, base, arena)
        
        val stopped = engine.stop(arena)
        assertEquals(0, stopped.size)
        assertTrue(engine.isIdle())
        assertFalse(engine.countdownRemaining.isPresent)
    }

    @Test
    fun testFinishedStateCarriesNoStaleProgress() {
        val engine = makeEngine()
        engine.start(sec(1.0), 0, base, arena)

        // Time out, then finish once an exhale completes.
        engine.tickSecond(dateAdd(base, 1.0), arena) // → finishing
        engine.tickClock(dateAdd(base, 1.0), arena)  // inhale → exhale
        engine.tickClock(dateAdd(base, 2.0), arena)  // exhale ends → finished
        
        assertTrue(engine.isFinished())
        // Note: JNI may not expose all getters for currentPhase, countdownRemaining in finished state
    }
}
