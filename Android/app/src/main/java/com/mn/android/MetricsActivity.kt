package com.mn.android

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
import com.mn.android.data.MeditateDatabase
import com.mn.android.data.toEntity
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
        // No System.loadLibrary here on purpose: every generated class already
        // loads the library from its own static initializer, and its LIB_NAME is
        // generated to match. Hardcoding a name here is what broke when the .so had
        // to be renamed: this one loaded a stale copy (or nothing) while the
        // generated code loaded the right one. libc++_shared.so comes along via
        // the library's NEEDED entry, so it needs no explicit load either.
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
    var reverseStatus by remember { mutableStateOf("reverse jni: untested") }

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

        // Reverse direction, on the same screen so one screenshot answers both
        // questions. 1 = Swift called Kotlin and got the expected string back.
        val reverse = runCatching { NativeProbe.reverseJNI() }.getOrElse { -2L }
        val store = runCatching { ReminderSettingsProbe.roundTrip(context) }
            .getOrElse { "store failed: ${it.javaClass.simpleName}: ${it.message}" }
        val notes = runCatching { NoteProbe.roundTrip(context) }
            .getOrElse { "note probe failed: ${it.javaClass.simpleName}: ${it.message}" }
        val streak = runCatching { StreakProbe.roundTrip(context) }
            .getOrElse { "streak probe failed: ${it.javaClass.simpleName}: ${it.message}" }
        val streakHeader = runCatching { StreakHeaderProbe.roundTrip(context) }
            .getOrElse { "streak header probe failed: ${it.javaClass.simpleName}: ${it.message}" }
        val sessions = runCatching { SessionProbe.roundTrip(context) }
            .getOrElse { "session probe failed: ${it.javaClass.simpleName}: ${it.message}" }
        reverseStatus = "reverse jni: $reverse\n$store\n$notes\n$streak\n$streakHeader\n$sessions"
    }

    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(status, style = MaterialTheme.typography.bodyMedium)
        Text(reverseStatus, style = MaterialTheme.typography.bodyMedium)
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