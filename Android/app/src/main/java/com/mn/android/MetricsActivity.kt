package com.mn.android.data

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.mn.android.data.AiDraftMetricEntity
import com.mn.core.AIDraftMetric
import com.mn.core.ErrorKind
import com.mn.core.InMemoryAIDraftMetricStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.swift.swiftkit.core.SwiftMemoryManagement

/**
 * Vertical slice check: Swift domain enum -> Kotlin mapping -> Room -> Compose.
 *
 * Rows go into Room from Kotlin and come back out of the Swift store, so a
 * failure anywhere in the JNI boundary, the mapping, or the DAO shows up as
 * wrong text on screen instead of an exception nobody reads.
 */
class MetricsActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        System.loadLibrary("MeditateAndNoteCore")
        System.loadLibrary("c++_shared")
        setContent {
            MaterialTheme {
                Surface(Modifier.fillMaxSize()) {
                    MetricsScreen()
                }
            }
        }
    }
}

@Composable
private fun MetricsScreen() {
    val context = LocalContext.current
    var rows by remember { mutableStateOf<List<AiDraftMetricEntity>>(emptyList()) }
    var status by remember { mutableStateOf("loading") }

    LaunchedEffect(Unit) {
        val dao = MeditateDatabase.get(context).aiDraftMetricDao()
        val arena = SwiftMemoryManagement.DEFAULT_SWIFT_JAVA_AUTO_ARENA
        // jextract maps Swift's public init(seed:) to init(...); the raw
        // constructor is private, so the factory is the only way in.
        val swiftStore = InMemoryAIDraftMetricStore.init(emptyArray(), arena)

        runCatching {
            withContext(Dispatchers.IO) {
                dao.deleteAll()

                // Kotlin -> Swift: enum cases built through JNI.
                swiftStore.record(
                    AIDraftMetric.generationCompleted(1234, 3, arena),
                ).get()
                swiftStore.record(
                    AIDraftMetric.generationFailed(
                        ErrorKind.timeout(arena),
                        arena,
                    ),
                ).get()

                // Swift -> Kotlin: back out of the Swift store, not the inputs.
                swiftStore.fetchAll(arena).get().map { it.toEntity() }
            }
        }.onSuccess { fromSwift ->
            withContext(Dispatchers.IO) { fromSwift.forEach { dao.insert(it) } }
            val stored = withContext(Dispatchers.IO) { dao.fetchAll() }
            rows = stored
            status = "swift returned ${fromSwift.size}, room stored ${stored.size}"
        }.onFailure { error ->
            status = "failed: ${error.javaClass.simpleName}: ${error.message}"
        }
    }

    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(status, style = MaterialTheme.typography.bodyMedium)
        LazyColumn(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            items(rows) { Text(it.describe(), style = MaterialTheme.typography.bodySmall) }
        }
    }
}

private fun AiDraftMetricEntity.describe(): String = buildString {
    append(kind)
    warmCold?.let { append(" warmCold=").append(it) }
    latencyMs?.let { append(" latencyMs=").append(it) }
    suggestionCount?.let { append(" suggestions=").append(it) }
    errorKind?.let { append(" error=").append(it) }
    suggestionIndex?.let { append(" index=").append(it) }
}