package com.mn.android

import android.app.Application
import com.mn.android.infrastructure.analytics.AppAnalytics
import com.mn.android.domain.events.DomainEventBus
import com.mn.android.infrastructure.analytics.AnalyticsEventMapper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class MnApplication : Application() {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    override fun onCreate() {
        super.onCreate()
        AppAnalytics.init(this)
        scope.launch {
            DomainEventBus.events.collect { event ->
                AnalyticsEventMapper.from(event)?.let(AppAnalytics::log)
            }
        }
    }
}
