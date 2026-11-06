package com.mn.android.reader

import com.mn.android.domain.reader.ReaderSettings
import com.mn.android.domain.reader.TextMeasurer

/** The reader's appearance preferences, without the SharedPreferences. */
class FakeReaderSettings : ReaderSettings {
    private var size = 18f
    private var paperName = "sepia"
    private var scroll = false

    override fun fontSize(): Float = size
    override fun setFontSize(size: Float) { this.size = size }
    override fun paper(): String = paperName
    override fun setPaper(name: String) { paperName = name }
    override fun scrollMode(): Boolean = scroll
    override fun setScrollMode(enabled: Boolean) { scroll = enabled }
}

/**
 * Fixed measurements: the reader only needs numbers, and a Paint on the test
 * side would measure differently on every device.
 */
class FakeTextMeasurer : TextMeasurer {
    override fun measure(text: String, fontSize: Double): Double = text.length * fontSize * 0.5
    override fun lineHeight(fontSize: Double): Double = fontSize * 1.45
}
