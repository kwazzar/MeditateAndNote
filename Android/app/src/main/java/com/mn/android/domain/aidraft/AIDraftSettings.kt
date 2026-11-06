package com.mn.android.domain.aidraft

/**
 * Where the AI draft provider lives: the endpoint, the model and the API key.
 *
 * The key never sits in SharedPreferences in the clear - the implementation
 * encrypts it with an Android Keystore key that cannot leave the device.
 */
interface AIDraftSettings {
    fun useHostedProvider(): Boolean
    fun setUseHostedProvider(value: Boolean)

    /** The hosted endpoint the build points at, empty when there is none. */
    fun hostedEndpoint(): String

    /** The endpoint the app talks to: the hosted proxy, or the user's own. */
    fun endpoint(): String

    /** The user's own endpoint, as typed in Settings. */
    fun userEndpoint(): String

    fun model(): String

    fun hasApiKey(): Boolean

    /** The decrypted key, or null when there is none or it cannot be read. */
    fun apiKey(): String?

    /**
     * Whether the user pointed the app at a provider. The API key is optional
     * - an endpoint without auth (a local model, a proxy) works without one.
     */
    fun isConfigured(): Boolean

    /** Empty [apiKey] clears the stored key; null leaves it as it is. */
    fun save(endpoint: String, model: String, apiKey: String?)
}
