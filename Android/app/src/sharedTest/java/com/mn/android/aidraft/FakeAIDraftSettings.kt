package com.mn.android.aidraft

import com.mn.android.domain.aidraft.AIDraftSettings

/** The provider settings without the SharedPreferences. */
class FakeAIDraftSettings(
    private var hosted: Boolean = false,
    private var endpoint: String = "http://localhost/v1/chat/completions",
    private var model: String = "mock-model",
    private var key: String? = null,
) : AIDraftSettings {

    override fun useHostedProvider(): Boolean = hosted
    override fun setUseHostedProvider(value: Boolean) { hosted = value }
    override fun hostedEndpoint(): String = "http://hosted/v1/chat/completions"
    override fun endpoint(): String = if (hosted) hostedEndpoint() else endpoint
    override fun userEndpoint(): String = endpoint
    override fun model(): String = model
    override fun hasApiKey(): Boolean = !key.isNullOrBlank()
    override fun apiKey(): String? = key
    override fun isConfigured(): Boolean = endpoint().isNotEmpty()
    override fun save(endpoint: String, model: String, apiKey: String?) {
        this.endpoint = endpoint
        this.model = model
        key = apiKey
    }
}
