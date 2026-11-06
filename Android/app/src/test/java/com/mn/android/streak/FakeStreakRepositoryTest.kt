package com.mn.android.streak

import com.mn.android.domain.streak.StreakRepository

class FakeStreakRepositoryTest : StreakRepositoryContract() {
    override fun createRepo(): StreakRepository = FakeStreakRepository()
}
