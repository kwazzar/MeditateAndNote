package com.mn.android.streak

import com.mn.android.data.streak.JniStreakRepository
import com.mn.android.domain.streak.StreakRepository
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class JniStreakRepositoryTest : StreakRepositoryContract() {
    override fun createRepo(): StreakRepository = JniStreakRepository()
}
