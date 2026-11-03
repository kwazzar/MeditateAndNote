#!/usr/bin/env python3
"""Runs the AI draft funnel over the GA4 Data API - the CLI equivalent of
Explore > Funnel exploration, without the menu.

Funnel: generation_started -> generation_completed -> suggestion_inserted,
broken down by warm vs cold generation. Requires the custom dimensions from
`Scripts/ga4-setup.sh` to be registered *before* the events were collected.

Auth (one-time; needs a browser):
    gcloud auth application-default login \
      --scopes=https://www.googleapis.com/auth/analytics.readonly,https://www.googleapis.com/auth/cloud-platform
    gcloud services enable analyticsdata.googleapis.com

Or pass a short-lived token from OAuth Playground (scope: analytics):
    Scripts/ga4-funnel.py 561496928 --token ya29...
    GA4_TOKEN=ya29... Scripts/ga4-funnel.py 561496928

Usage:
    Scripts/ga4-funnel.py 561496928 [--days 28] [--token ya29...]
    Scripts/ga4-funnel.py 561496928 --events   # every ai_draft_metric outcome
"""

import json
import os
import subprocess
import sys
from datetime import date, timedelta
from urllib import request

# runFunnelReport only exists in v1alpha (v1beta has runReport/runPivotReport).
API = "https://analyticsdata.googleapis.com/v1alpha"
_CACHED = None


def arg_value(flag: str):
    for i, arg in enumerate(sys.argv):
        if arg == flag and i + 1 < len(sys.argv):
            return sys.argv[i + 1]
        if arg.startswith(flag + "="):
            return arg.split("=", 1)[1]
    return None


def token() -> str:
    """--token wins over GA4_TOKEN, which wins over gcloud ADC, so a
    short-lived OAuth token can be used when the gcloud default client ID is
    blocked for the analytics scopes."""
    global _CACHED
    if _CACHED:
        return _CACHED
    value = arg_value("--token")
    if value:
        print(f"auth: --token {mask(value)}", file=sys.stderr)
        _CACHED = value
        return value
    if os.environ.get("GA4_TOKEN"):
        _CACHED = os.environ["GA4_TOKEN"]
        print(f"auth: GA4_TOKEN {mask(_CACHED)}", file=sys.stderr)
        return _CACHED
    try:
        value = subprocess.check_output(
            ["gcloud", "auth", "application-default", "print-access-token"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
        _CACHED = value
        print(f"auth: gcloud ADC {mask(value)}", file=sys.stderr)
        return value
    except (OSError, subprocess.CalledProcessError):
        raise SystemExit(
            "no credentials: pass --token ya29... (or GA4_TOKEN='ya29...', or "
            "`gcloud auth application-default login` with the analytics scope)"
        )


def mask(value: str) -> str:
    return f"…{value[-4:]}" if len(value) > 4 else "…"


def step(name: str, metric_type: str) -> dict:
    return {
        "name": name,
        "filterExpression": {
            "andGroup": {
                "expressions": [
                    {"funnelEventFilter": {"eventName": "ai_draft_metric"}},
                    {"funnelFieldFilter": {
                        "fieldName": "customEvent:metric_type",
                        "stringFilter": {"matchType": "EXACT", "value": metric_type},
                    }},
                ]
            }
        },
    }


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__.strip().split("Usage:")[-1].strip(), file=sys.stderr)
        return 2
    property_id = sys.argv[1]
    days = 28
    if "--days" in sys.argv:
        days = int(sys.argv[sys.argv.index("--days") + 1])

    date_range = {
        "startDate": (date.today() - timedelta(days=days)).isoformat(),
        "endDate": date.today().isoformat(),
    }
    if "--events" in sys.argv:
        return run(
            f"{API}/properties/{property_id}:runReport",
            {
                "dateRanges": [date_range],
                "dimensions": [
                    {"name": "eventName"},
                    {"name": "customEvent:metric_type"},
                    {"name": "customEvent:error_kind"},
                    {"name": "customEvent:warm_cold"},
                ],
                "metrics": [{"name": "eventCount"}, {"name": "totalUsers"}],
                "dimensionFilter": {"filter": {
                    "fieldName": "eventName",
                    "stringFilter": {"matchType": "EXACT", "value": "ai_draft_metric"},
                }},
                "orderBys": [{"metric": {"metricName": "eventCount"}, "desc": True}],
                "limit": 100,
            },
        )

    body = {
        "dateRanges": [date_range],
        "funnel": {
            "isOpenFunnel": False,
            "steps": [
                step("generation_started", "generation_started"),
                step("generation_completed", "generation_completed"),
                step("suggestion_inserted", "suggestion_inserted"),
            ],
        },
        "funnelBreakdown": {
            "breakdownDimension": {"name": "customEvent:warm_cold"}
        },
        "funnelVisualizationType": "STANDARD_FUNNEL",
    }

    return run(
        f"{API}/properties/{property_id}:runFunnelReport",
        body,
        table_key="funnelTable",
        empty="no funnel data yet (events need 24-48h to appear, or the custom "
              "dimension was registered after the events were collected)",
    )


def run(url: str, body: dict, table_key: str = "", empty: str = "no rows") -> int:
    req = request.Request(
        url,
        data=json.dumps(body).encode(),
        headers={"Authorization": f"Bearer {token()}",
                 "Content-Type": "application/json"},
    )
    try:
        with request.urlopen(req) as response:
            payload = json.load(response)
    except Exception as error:  # noqa: BLE001 - surface the API message verbatim
        detail = getattr(error, "read", lambda: b"")()
        print(f"{error}\n{detail.decode(errors='replace')}", file=sys.stderr)
        if b"insufficient authentication scopes" in detail:
            try:
                with request.urlopen(
                    f"https://oauth2.googleapis.com/tokeninfo?access_token={token()}"
                ) as info:
                    print(f"granted scopes: {json.load(info).get('scope')}", file=sys.stderr)
            except Exception:  # noqa: BLE001 - diagnostics must not mask the real error
                pass
            print(
                "need https://www.googleapis.com/auth/analytics.readonly or "
                "https://www.googleapis.com/auth/analytics",
                file=sys.stderr,
            )
        return 1

    table = payload.get(table_key, payload)
    dims = [h.get("name") for h in table.get("dimensionHeaders", [])]
    metrics = [h.get("name") for h in table.get("metricHeaders", [])]
    rows = table.get("rows", [])

    if not rows:
        print(empty)
        return 0

    print("\t".join(dims + metrics))
    for row in rows:
        values = [d.get("value", "") for d in row.get("dimensionValues", [])]
        values += [m.get("value", "") for m in row.get("metricValues", [])]
        print("\t".join(values))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
