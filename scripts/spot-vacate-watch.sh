c#!/usr/bin/env bash
# Poll EC2 IMDSv2 for a spot interruption notice and print one line when it lands.
# Designed as a Monitor command: every stdout line becomes a notification, and the
# script exits as soon as the vacate is seen (nothing useful follows it).
#
#   INTERVAL   seconds between polls (default 20; the vacate window is ~120s)
#   REBALANCE  1 = also report a rebalance recommendation, which precedes the
#              real notice by minutes and is the earlier drain signal (default 0)
#
# Exit codes: 0 = vacate seen (payload printed), 124 = IMDS unreachable too long.
set -u

INTERVAL=${INTERVAL:-20}
REBALANCE=${REBALANCE:-0}
IMDS=${IMDS:-http://169.254.169.254/latest}
MAX_IMDS_FAIL=${MAX_IMDS_FAIL:-30}   # consecutive failures before giving up

fails=0
rebalance_seen=0

# IMDSv2 tokens expire, so fetch a fresh one each pass rather than caching.
imds_token() {
  curl -s -X PUT "$IMDS/api/token" \
       -H "X-aws-ec2-metadata-token-ttl-seconds: 60" --max-time 3 2>/dev/null
}

# echoes the HTTP status; body (if any) goes to the named file
imds_get() {
  curl -s -o "$2" -w '%{http_code}' -H "X-aws-ec2-metadata-token: $1" \
       --max-time 3 "$IMDS/meta-data/$3" 2>/dev/null
}

body=$(mktemp)
trap 'rm -f "$body"' EXIT

while true; do
  tok=$(imds_token)
  if [ -z "$tok" ]; then
    fails=$((fails + 1))
    # Don't die on a single blip -- IMDS refuses briefly under load.
    if [ "$fails" -ge "$MAX_IMDS_FAIL" ]; then
      echo "IMDS UNREACHABLE: no token for $((fails * INTERVAL))s, giving up"
      exit 124
    fi
    sleep "$INTERVAL"; continue
  fi
  fails=0

  code=$(imds_get "$tok" "$body" spot/instance-action)
  if [ "$code" = "200" ]; then
    # {"action":"terminate","time":"2026-08-26T10:32:17Z"} -- print it verbatim
    echo "SPOT VACATE: $(cat "$body")"
    exit 0
  fi

  if [ "$REBALANCE" = "1" ] && [ "$rebalance_seen" = "0" ]; then
    code=$(imds_get "$tok" "$body" events/recommendations/rebalance)
    if [ "$code" = "200" ]; then
      echo "SPOT REBALANCE: $(cat "$body")"
      rebalance_seen=1   # fires once; the vacate notice is the real stop signal
    fi
  fi

  sleep "$INTERVAL"
done
