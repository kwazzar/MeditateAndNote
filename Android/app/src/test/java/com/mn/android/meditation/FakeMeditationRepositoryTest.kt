package com.mn.android.meditation

class FakeMeditationRepositoryTest : MeditationRepositoryContract() {
    override fun createRepo() = FakeMeditationRepository()
}