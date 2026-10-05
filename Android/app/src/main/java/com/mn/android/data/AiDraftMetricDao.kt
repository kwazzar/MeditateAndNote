package com.mn.android.data

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query

@Dao
interface AiDraftMetricDao {
    @Insert
    suspend fun insert(metric: AiDraftMetricEntity): Long

    @Query("SELECT * FROM ai_draft_metrics ORDER BY id DESC")
    suspend fun fetchAll(): List<AiDraftMetricEntity>

    @Query("DELETE FROM ai_draft_metrics")
    suspend fun deleteAll()
}