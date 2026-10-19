package com.mn.android.data

import java.io.BufferedReader
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONObject

/**
 * Kotlin side of the AI draft transport.
 *
 * Swift owns the domain: it builds the request body, applies the quota rule
 * and parses the model's answer. This file only moves bytes - it reads the
 * endpoint and the model the user configured, posts the body Swift built and
 * hands the raw response back.
 *
 * The API key never crosses the JNI boundary: it is read from the Keystore
 * here and attached to the request.
 */
object AIDraftProvider {

    init {
        // Force the .so load: the editor can be the first JNI touch of the
        // process (same trick as NoteEditorSource).
        Class.forName("com.mn.core.AIDraftMetric")
    }

    /** `{"endpoint": "…", "model": "…"}` - empty values mean "use the defaults". */
    @JvmStatic
    fun settings(): String = JSONObject().apply {
        put("endpoint", AIDraftSettingsStore.endpoint())
        put("model", AIDraftSettingsStore.model())
    }.toString()

    /** `{"ok": true, "body": "…"}` or `{"ok": false, "status": 429}`. */
    @JvmStatic
    fun post(endpoint: String, body: String): String {
        val result = try {
            transport(endpoint, body)
        } catch (error: Exception) {
            TransportResult(ok = false, status = 0, body = "")
        }
        return JSONObject().apply {
            put("ok", result.ok)
            put("status", result.status)
            put("body", result.body)
        }.toString()
    }

    /**
     * The transport seam. An instrumented test replaces it with a stub: a
     * test process on Android cannot host an HTTP server to answer a POST.
     */
    @Volatile
    var transport: (String, String) -> TransportResult = ::httpPost

    data class TransportResult(val ok: Boolean, val status: Int, val body: String)

    private fun httpPost(endpoint: String, body: String): TransportResult {
        val connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = CONNECT_TIMEOUT_MS
            readTimeout = READ_TIMEOUT_MS
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
            AIDraftSettingsStore.apiKey()?.takeIf { it.isNotBlank() }?.let {
                setRequestProperty("Authorization", "Bearer $it")
            }
        }
        try {
            connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val text = stream?.bufferedReader()?.use(BufferedReader::readText).orEmpty()
            return TransportResult(ok = status in 200..299, status = status, body = text)
        } finally {
            connection.disconnect()
        }
    }

    private const val CONNECT_TIMEOUT_MS = 30_000
    private const val READ_TIMEOUT_MS = 60_000
}
