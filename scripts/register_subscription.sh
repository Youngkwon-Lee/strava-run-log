#!/usr/bin/env bash
set -euo pipefail

: "${STRAVA_CLIENT_ID:?missing}"
: "${STRAVA_CLIENT_SECRET:?missing}"
: "${STRAVA_VERIFY_TOKEN:?missing}"
: "${WEBHOOK_CALLBACK_URL:?missing}" # e.g. https://xxx.vercel.app/api/strava/webhook

curl -sS -X POST https://www.strava.com/api/v3/push_subscriptions \
  -F client_id="$STRAVA_CLIENT_ID" \
  -F client_secret="$STRAVA_CLIENT_SECRET" \
  -F callback_url="$WEBHOOK_CALLBACK_URL" \
  -F verify_token="$STRAVA_VERIFY_TOKEN"

echo
