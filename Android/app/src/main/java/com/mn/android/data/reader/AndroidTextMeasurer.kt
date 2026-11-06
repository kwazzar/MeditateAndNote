package com.mn.android.data.reader

import com.mn.android.data.TextMetrics
import com.mn.android.domain.reader.TextMeasurer

/**
 * The platform text measurement, behind the domain's [TextMeasurer].
 *
 * `TextMetrics` stays where it is: the Swift pagination engine calls it by
 * its class name through reverse JNI.
 */
class AndroidTextMeasurer : TextMeasurer {
    override fun measure(text: String, fontSize: Double): Double = TextMetrics.measure(text, fontSize)
    override fun lineHeight(fontSize: Double): Double = TextMetrics.lineHeight(fontSize)
}
