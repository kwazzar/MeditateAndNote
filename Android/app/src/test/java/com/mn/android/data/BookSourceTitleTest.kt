package com.mn.android.data

import org.junit.Assert.assertEquals
import org.junit.Test

class BookSourceTitleTest {

    @Test
    fun humanizesFileNames() {
        assertEquals("Import", displayTitleForLibrary("import."))
        assertEquals("Marcus Aurelius", displayTitleForLibrary("Marcus_Aurelius"))
        assertEquals("Very long book name", displayTitleForLibrary("very-long_book-name.txt"))
        assertEquals("Quiet Sky", displayTitleForLibrary("Quiet Sky"))
    }

    @Test
    fun keepsInternalTitles() {
        assertEquals("Марк Аврелій", displayTitleForLibrary("Марк Аврелій"))
        assertEquals("Continuum", displayTitleForLibrary("Continuum"))
    }
}
