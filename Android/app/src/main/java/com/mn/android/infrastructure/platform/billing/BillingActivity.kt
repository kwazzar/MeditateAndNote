package com.mn.android.infrastructure.platform.billing

import android.app.Activity

/**
 * The activity the billing sheet is launched from.
 *
 * Google Play Billing needs a foreground [Activity] to show the purchase
 * dialog, and the SDK cannot find one on its own. The app has exactly one
 * user-facing activity (`MainActivity`), so it registers itself here and the
 * billing adapter asks for it when a purchase starts.
 *
 * Held weakly-ish: the reference is cleared when the activity is destroyed,
 * so a purchase attempt after teardown finds no activity and reports a
 * failure instead of leaking the window.
 */
object BillingActivity {

    @Volatile
    var current: Activity? = null
}
