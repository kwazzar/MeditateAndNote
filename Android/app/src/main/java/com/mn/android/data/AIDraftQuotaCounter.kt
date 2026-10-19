package com.mn.android.data

import android.content.Context
import org.json.JSONObject

/**
 * The free-tier counter for AI drafts: how many generations are used up.
 *
 * Kotlin owns the storage, Core owns the rule and the limit - the bridge asks
 * for the count and applies `AIDraftQuota.allowsDraft(isPremium:used:)`. The
 * counter is a restriction, never an authority: it can only block a
 * generation, never grant one.
 */
object AIDraftQuotaCounter {

    private const val PREFS = "ai_draft_quota"
    private const val KEY_USED = "used"

    private var context: Context? = null

    fun configure(context: Context) {
        this.context = context.applicationContext
    }

    /** `{"used": 3}` - JSON, so the count crosses JNI as a string. */
    @JvmStatic
    fun state(): String = JSONObject().put("used", used()).toString()

    @JvmStatic
    fun record() {
        val prefs = prefs() ?: return
        prefs.edit().putInt(KEY_USED, used() + 1).apply()
    }

    /** Test seam: the count starts from zero. */
    fun reset() {
        prefs()?.edit()?.remove(KEY_USED)?.apply()
    }

    fun used(): Int = prefs()?.getInt(KEY_USED, 0) ?: 0

    private fun prefs() = context?.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
