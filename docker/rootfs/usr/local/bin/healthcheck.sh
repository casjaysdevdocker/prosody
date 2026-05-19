#!/usr/bin/env bash
# healthcheck.sh — container health probe
# Returns 0 (healthy) if prosody's HTTP health endpoint responds 200

: "${PROSODY_HTTP_PORT:=5280}"

curl -q -LSs --max-time 5 "http://127.0.0.1:${PROSODY_HTTP_PORT}/health" -o /dev/null
