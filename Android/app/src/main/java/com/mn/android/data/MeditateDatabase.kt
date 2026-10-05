package com.mn.android.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(entities = [AiDraftMetricEntity::class], version = 1, exportSchema = false)
abstract class MeditateDatabase : RoomDatabase() {
    abstract fun aiDraftMetricDao(): AiDraftMetricDao

    companion object {
        @Volatile
        private var instance: MeditateDatabase? = null

        fun get(context: Context): MeditateDatabase =
            instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    MeditateDatabase::class.java,
                    "meditate.db",
                ).build().also { instance = it }
            }
    }
}