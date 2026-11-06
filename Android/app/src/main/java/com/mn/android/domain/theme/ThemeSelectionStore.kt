package com.mn.android.domain.theme

import com.mn.android.domain.theme.model.MainTheme

/** Where the picked theme lives. */
interface ThemeSelectionStore {
    var selected: MainTheme
}
