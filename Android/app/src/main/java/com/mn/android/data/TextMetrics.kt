package com.mn.android.data

import kotlin.math.roundToInt

/**
 * Font metrics for the Swift `PaginationEngine` on Android.
 *
 * Swift paginates (the engine lives in the shared Core package); it asks this
 * object for per-word widths and the line height, one reverse-JNI call per
 * query. Results are cached per (fontSize, text) — a book's word list is
 * finite, so steady-state pagination hits only the cache.
 *
 * `ponytail:` per-word JNI round trips on cache misses, ~20µs each — a very
 * large book paginates in well under a second on a background thread; batch
 * the word list in one call only if that ever measurably hurts.
 */
object TextMetrics {

    @Volatile
    private var cache: HashMap<String, Double> = HashMap()

    @Volatile
    private var lineHeightCache: HashMap<Double, Double> = HashMap()

    @JvmStatic
    fun measure(text: String, fontSize: Double): Double {
        val key = "$fontSize|$text"
        cache[key]?.let { return it }

        val width = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
            textSize = fontSize.toFloat()
        }.measureText(text).toDouble()

        synchronized(cache) {
            cache[key] = width
        }
        return width
    }

    @JvmStatic
    fun lineHeight(fontSize: Double): Double {
        lineHeightCache[fontSize]?.let { return it }

        val metrics = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
            textSize = fontSize.toFloat()
        }.fontMetrics

        val height = ((metrics.descent - metrics.ascent) * 1.45).roundToInt().toDouble()
        synchronized(lineHeightCache) {
            lineHeightCache[fontSize] = height
        }
        return height
    }
}
