package com.mn.android.aidraft

class FakeAIDraftRepositoryTest : AIDraftRepositoryContract() {
    override fun createRepo() = FakeAIDraftRepository()
}
