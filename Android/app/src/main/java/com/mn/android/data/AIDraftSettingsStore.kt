package com.mn.android.data

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

/**
 * Where the AI draft provider lives: the endpoint, the model and the API key.
 *
 * The key never sits in SharedPreferences in the clear - it is encrypted with
 * an AES key that lives in the Android Keystore and cannot leave it. The
 * endpoint and the model are not secrets and stay in SharedPreferences.
 *
 * Swift side: `AIDraftProvider.settings` in AiInsightsBridge-adjacent code
 * (AIDraftBridge.swift) reads the endpoint and the model; the key stays on
 * this side and is attached to the request here.
 */
object AIDraftSettingsStore {

    private const val PREFS = "ai_draft_settings"
    private const val KEY_ENDPOINT = "endpoint"
    private const val KEY_MODEL = "model"
    private const val KEY_CIPHER = "api_key_cipher"
    private const val KEY_IV = "api_key_iv"
    private const val KEY_ALIAS = "ai_draft_api_key"

    private var context: Context? = null

    fun configure(context: Context) {
        this.context = context.applicationContext
    }

    fun endpoint(): String = prefs()?.getString(KEY_ENDPOINT, "").orEmpty()

    fun model(): String = prefs()?.getString(KEY_MODEL, "").orEmpty()

    fun hasApiKey(): Boolean = !apiKey().isNullOrBlank()

    /** Empty [apiKey] clears the stored key; null leaves it as it is. */
    fun save(endpoint: String, model: String, apiKey: String?) {
        val prefs = prefs() ?: return
        prefs.edit()
            .putString(KEY_ENDPOINT, endpoint.trim())
            .putString(KEY_MODEL, model.trim())
            .apply()
        if (apiKey != null) {
            if (apiKey.isBlank()) clearApiKey() else storeApiKey(apiKey)
        }
    }

    fun clearApiKey() {
        prefs()?.edit()?.remove(KEY_CIPHER)?.remove(KEY_IV)?.apply()
    }

    /** The decrypted key, or null when there is none or it cannot be read. */
    fun apiKey(): String? {
        val prefs = prefs() ?: return null
        val cipherText = prefs.getString(KEY_CIPHER, null) ?: return null
        val ivText = prefs.getString(KEY_IV, null) ?: return null
        return try {
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(
                Cipher.DECRYPT_MODE,
                keystoreKey(),
                javax.crypto.spec.GCMParameterSpec(128, Base64.decode(ivText, Base64.NO_WRAP)),
            )
            String(
                cipher.doFinal(Base64.decode(cipherText, Base64.NO_WRAP)),
                Charsets.UTF_8,
            )
        } catch (error: Exception) {
            // A key that cannot be decrypted (rotated, corrupted) is treated as
            // no key: the provider answers "unavailable" instead of crashing.
            null
        }
    }

    // MARK: - Keystore

    private fun storeApiKey(plain: String) {
        val prefs = prefs() ?: return
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, keystoreKey())
        val encrypted = cipher.doFinal(plain.toByteArray(Charsets.UTF_8))
        prefs.edit()
            .putString(KEY_CIPHER, Base64.encodeToString(encrypted, Base64.NO_WRAP))
            .putString(KEY_IV, Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
            .apply()
    }

    private fun keystoreKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        (keyStore.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry)?.let { return it.secretKey }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build(),
        )
        return generator.generateKey()
    }

    private fun prefs() = context?.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private const val ANDROID_KEYSTORE = "AndroidKeyStore"
    private const val TRANSFORMATION = "AES/GCM/NoPadding"
}
