#!/bin/bash
#
# Configures a GA4 property over the Admin API instead of clicking through
# Admin > Custom definitions: 14-month data retention plus the event-scoped
# dimensions/metrics the analytics events rely on. Idempotent - re-running
# creates only what is missing.
#
# Event parameters must match `AnalyticsEventMapper` on both platforms.
# Registration is not retroactive: parameters collected before this run stay
# unregistered in reports.
#
# Auth (one-time; needs a browser):
#   gcloud auth application-default login \
#     --scopes=https://www.googleapis.com/auth/analytics.edit,https://www.googleapis.com/auth/cloud-platform
#   gcloud services enable analyticsadmin.googleapis.com
#
# Usage:
#   Scripts/ga4-setup.sh 561496928
#
set -euo pipefail

PROPERTY_ID="${1:?usage: $0 <GA4 property id>}"
API="https://analyticsadmin.googleapis.com/v1beta"
TOKEN="${GA4_TOKEN:-$(gcloud auth application-default print-access-token)}"

command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

api() {
    curl -sS --fail-with-body \
        -H "Authorization: Bearer $TOKEN" \
        -H 'Content-Type: application/json' \
        "$@"
}

echo "property $PROPERTY_ID: retention -> 14 months"
api -X PATCH \
    "$API/properties/$PROPERTY_ID/dataRetentionSettings?updateMask=eventDataRetention" \
    -d '{"eventDataRetention":"FOURTEEN_MONTHS"}' >/dev/null

EXISTING_DIMENSIONS="$(api "$API/properties/$PROPERTY_ID/customDimensions?pageSize=200" \
    | jq -r '.customDimensions[]?.parameterName')"
EXISTING_METRICS="$(api "$API/properties/$PROPERTY_ID/customMetrics?pageSize=200" \
    | jq -r '.customMetrics[]?.parameterName')"

ensure_dimension() {
    local param="$1" display="$2"
    if grep -qx "$param" <<<"$EXISTING_DIMENSIONS"; then
        echo "dimension exists: $param"
        return
    fi
    api -X POST "$API/properties/$PROPERTY_ID/customDimensions" \
        -d "{\"parameterName\":\"$param\",\"displayName\":\"$display\",\"scope\":\"EVENT\"}" >/dev/null
    echo "dimension created: $param"
}

ensure_metric() {
    local param="$1" display="$2" unit="$3"
    if grep -qx "$param" <<<"$EXISTING_METRICS"; then
        echo "metric exists: $param"
        return
    fi
    api -X POST "$API/properties/$PROPERTY_ID/customMetrics" \
        -d "{\"parameterName\":\"$param\",\"displayName\":\"$display\",\"scope\":\"EVENT\",\"measurementUnit\":\"$unit\"}" >/dev/null
    echo "metric created: $param"
}

ensure_user_dimension() {
    local param="$1" display="$2"
    if grep -qx "$param" <<<"$EXISTING_DIMENSIONS"; then
        echo "user dimension exists: $param"
        return
    fi
    api -X POST "$API/properties/$PROPERTY_ID/customDimensions" \
        -d "{\"parameterName\":\"$param\",\"displayName\":\"$display\",\"scope\":\"USER\"}" >/dev/null
    echo "user dimension created: $param"
}

ensure_dimension metric_type      "AI metric type"
ensure_dimension warm_cold        "AI warm cold"
ensure_dimension error_kind       "AI error kind"
ensure_dimension meditation_id    "Meditation id"
ensure_dimension book_format      "Book format"
ensure_dimension bookmark_type    "Bookmark type"

ensure_user_dimension onboarding_completed "Onboarding completed"
ensure_user_dimension premium_status       "Premium status"
ensure_user_dimension streak_bucket        "Streak bucket"

ensure_metric latency_ms          "AI latency"            MILLISECONDS
ensure_metric suggestion_count    "AI suggestions"        STANDARD
ensure_metric index               "AI suggestion index"   STANDARD
ensure_metric duration_seconds    "Meditation duration"   SECONDS
ensure_metric streak_days         "Streak days"           STANDARD
ensure_metric previous_streak_days "Previous streak days" STANDARD

echo "done. GA4 reports pick these up for events collected from now on."
