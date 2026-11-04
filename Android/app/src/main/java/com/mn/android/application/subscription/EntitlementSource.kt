package com.mn.android.application.subscription

import android.content.Context

/**
 * The premium entitlement, readable from the JNI side.
 *
 * The AI draft flow is orchestrated in Swift (`AIDraftBridge`), and the free
 * quota rule is Core's (`AIDraftQuota.allowsDraft`). Both need to know
 * whether the user is pro, and the subscription state is Kotlin's - the same
 * division of labour as `AIDraftQuotaCounter`: Kotlin owns the state, Core
 * owns the rule.
 *
 * The value is a string, not a boolean: the JNI bridge exchanges strings, so
 * no type has to be mapped across the boundary.
 */
object EntitlementSource {

    @Volatile
    private var context: Context? = null

    fun configure(context: Context) {
        this.context = context.applicationContext
    }

    /** "true" when the `pro` entitlement is active. */
    @JvmStatic
    fun isPro(): String {
        val ctx = context ?: return "false"
        return if (SubscriptionScope.manager(ctx).isPro) "true" else "false"
    }
}
