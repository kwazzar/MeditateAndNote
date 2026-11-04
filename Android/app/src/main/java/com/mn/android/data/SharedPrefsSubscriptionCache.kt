package com.mn.android.data

import android.content.Context
import com.mn.android.domain.subscription.Entitlement
import com.mn.android.domain.subscription.SubscriptionCache
import com.mn.android.domain.subscription.SubscriptionStatus
import org.json.JSONObject

/**
 * Persists the last-known [SubscriptionStatus] for offline/fast startup.
 *
 * The Android counterpart of iOS `UserDefaultsSubscriptionCache`
 * (`MeditateAndNote/Persistence/UserDefaultsSubscriptionCache.swift`), on
 * SharedPreferences instead of UserDefaults.
 *
 * UX fast-path only: corrupted or missing data degrades to null (free), and
 * it is never an authority for granting an entitlement - only a refresh
 * through the provider may do that.
 */
class SharedPrefsSubscriptionCache(context: Context) : SubscriptionCache {

    private val prefs = context.applicationContext
        .getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    override fun load(): SubscriptionStatus? {
        val json = prefs.getString(KEY, null) ?: return null
        return try {
            val obj = JSONObject(json)
            SubscriptionStatus(
                activeEntitlements = obj.optJSONArray(ENTITLEMENTS)
                    ?.let { array ->
                        buildSet {
                            for (i in 0 until array.length()) {
                                Entitlement.fromId(array.optString(i))?.let(::add)
                            }
                        }
                    }
                    ?: emptySet(),
                expirationDate = if (obj.has(EXPIRATION)) obj.optLong(EXPIRATION) else null,
                willRenew = obj.optBoolean(WILL_RENEW, false),
                productIdentifier = obj.optString(PRODUCT, "").ifEmpty { null },
            )
        } catch (error: Exception) {
            // A corrupted cache is "unknown", never a crash and never a grant.
            null
        }
    }

    override fun save(status: SubscriptionStatus) {
        val entitlements = org.json.JSONArray()
        status.activeEntitlements.forEach { entitlements.put(it.id) }
        val obj = JSONObject()
            .put(ENTITLEMENTS, entitlements)
            .put(WILL_RENEW, status.willRenew)
        status.expirationDate?.let { obj.put(EXPIRATION, it) }
        status.productIdentifier?.let { obj.put(PRODUCT, it) }
        prefs.edit().putString(KEY, obj.toString()).apply()
    }

    /** Test seam: forget the stored status. */
    fun clear() {
        prefs.edit().remove(KEY).apply()
    }

    private companion object {
        const val PREFS = "subscription"
        const val KEY = "subscription.status.v1"
        const val ENTITLEMENTS = "activeEntitlements"
        const val EXPIRATION = "expirationDate"
        const val WILL_RENEW = "willRenew"
        const val PRODUCT = "productIdentifier"
    }
}
