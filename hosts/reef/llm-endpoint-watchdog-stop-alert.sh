#!/run/current-system/sw/bin/bash
# Fail-closed watchdog for Reef's vLLM endpoint.
# Confirm a dead/wedged engine, stop it once, alert, and leave it parked.
set -uo pipefail

DOCKER=${DOCKER:-docker}
CURL=${CURL:-curl}
DATE=${DATE:-date}
STATE_DIR=${STATE_DIR:-/var/lib/llm-endpoint-watchdog}
TELEGRAM_ENV=${TELEGRAM_ENV:-/etc/telegram/alerts.env}
PORTS=${PORTS:-8010}
GRACE=${GRACE:-600}
FAIL_THRESHOLD=${FAIL_THRESHOLD:-3}
STOP_TIMEOUT=${STOP_TIMEOUT:-15}

mkdir -p "$STATE_DIR"
chmod 0700 "$STATE_DIR" 2>/dev/null || true

ts() { "$DATE" -u +%Y-%m-%dT%H:%M:%SZ; }
log() { printf '%s %s\n' "$(ts)" "$*"; }

send_telegram() {
  local text=$1 code
  if [ ! -r "$TELEGRAM_ENV" ]; then
    log "ALERT_FAILED reason=missing_telegram_env path=$TELEGRAM_ENV"
    return 1
  fi

  # shellcheck disable=SC1090
  . "$TELEGRAM_ENV"
  if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_HOME_CHANNEL:-}" ] || [ -z "${TELEGRAM_CRON_THREAD_ID:-}" ]; then
    log "ALERT_FAILED reason=incomplete_telegram_env"
    return 1
  fi

  code="$($CURL -sS --max-time 15 -o /dev/null -w '%{http_code}' \
    -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_HOME_CHANNEL}" \
    --data-urlencode "message_thread_id=${TELEGRAM_CRON_THREAD_ID}" \
    --data-urlencode "text=${text}" || echo 000)"
  log "telegram_http=$code"
  [ "$code" = "200" ]
}

if [ "${1:-}" = "--test-alert" ]; then
  send_telegram "✅ Reef vLLM watchdog test

Mode: stop and alert; no automatic restart
Endpoint: :8010
Engine action: none (delivery test only)"
  exit $?
fi

for port in $PORTS; do
  row="$($DOCKER ps --filter "publish=$port" --format '{{.ID}} {{.Names}}' 2>/dev/null | sed -n '1p')"
  cid=${row%% *}
  name=${row#* }
  if [ -z "$row" ] || [ "$cid" = "$row" ]; then
    # A missing publisher is treated as deliberately parked. Never resurrect it.
    log "parked port=$port action=none"
    continue
  fi

  state="$STATE_DIR/port-$port.state"
  started="$($DOCKER inspect -f '{{.State.StartedAt}}' "$cid" 2>/dev/null || true)"
  started_sec=0
  if [ -n "$started" ]; then
    started_sec="$($DATE -d "$started" +%s 2>/dev/null || echo 0)"
  fi
  now_sec="$($DATE +%s)"
  age=$((now_sec - started_sec))

  if [ "$started_sec" -gt 0 ] && [ "$age" -lt "$GRACE" ]; then
    printf 'container_id=%s\nprev_gen=0\nprev_run=0\napi_strike=0\nwedge_strike=0\n' "$cid" > "$state"
    chmod 0600 "$state" 2>/dev/null || true
    log "grace port=$port container=$name age=${age}s action=none"
    continue
  fi

  container_id=""; prev_gen=0; prev_run=0; api_strike=0; wedge_strike=0
  if [ -r "$state" ]; then
    # Root-owned state under StateDirectory; values are numeric/container ID only.
    # shellcheck disable=SC1090
    . "$state" || true
  fi
  if [ "$container_id" != "$cid" ]; then
    prev_gen=0; prev_run=0; api_strike=0; wedge_strike=0
  fi

  base="http://127.0.0.1:$port"
  code="$($CURL -sS -o /dev/null -w '%{http_code}' --max-time 5 "$base/v1/models" 2>/dev/null || echo 000)"
  code=${code: -3}
  running=0
  gen=0
  reason=""

  if [ "$code" != "200" ]; then
    api_strike=$((api_strike + 1))
    wedge_strike=0
    reason="API HTTP $code for $api_strike consecutive checks"
  else
    api_strike=0
    metrics="$($CURL -fsS --max-time 5 "$base/metrics" 2>/dev/null || true)"
    if [ -n "$metrics" ]; then
      running="$(printf '%s\n' "$metrics" | sed -n 's/^vllm:num_requests_running{.*} //p' | sed -n '$p')"
      gen="$(printf '%s\n' "$metrics" | sed -n 's/^vllm:generation_tokens_total{.*} //p' | sed -n '$p')"
      running=${running%%.*}; gen=${gen%%.*}
      running=${running:-0}; gen=${gen:-0}
    fi

    if [ "$running" -ge 1 ] && [ "$prev_run" -ge 1 ] && [ "$gen" -le "$prev_gen" ]; then
      wedge_strike=$((wedge_strike + 1))
      reason="generation stagnant with $running running request(s) for $wedge_strike consecutive checks"
    else
      wedge_strike=0
    fi
  fi

  printf 'container_id=%s\nprev_gen=%s\nprev_run=%s\napi_strike=%s\nwedge_strike=%s\n' \
    "$cid" "$gen" "$running" "$api_strike" "$wedge_strike" > "$state"
  chmod 0600 "$state" 2>/dev/null || true

  if [ "$api_strike" -lt "$FAIL_THRESHOLD" ] && [ "$wedge_strike" -lt "$FAIL_THRESHOLD" ]; then
    log "healthy port=$port container=$name http=$code running=$running gen=$gen api_strike=$api_strike wedge_strike=$wedge_strike action=none"
    continue
  fi

  log "CONFIRMED_UNHEALTHY port=$port container=$name reason=$reason action=stop"
  stop_result="stopped"
  if ! "$DOCKER" stop --time "$STOP_TIMEOUT" "$cid" >/dev/null 2>&1; then
    stop_result="stop_failed_kill_attempted"
    "$DOCKER" kill "$cid" >/dev/null 2>&1 || true
  fi

  running_after="$($DOCKER inspect -f '{{.State.Running}}' "$cid" 2>/dev/null || echo unknown)"
  if [ "$running_after" != "false" ]; then
    stop_result="FAILED_running=$running_after"
  fi

  alert="🚨 Reef vLLM parked by watchdog

Endpoint: :$port
Container: $name
Reason: $reason
Action: $stop_result; automatic restart suppressed

Manual recovery only after checking Reef:
~/bin/launch-vllm-llmfan-heretic-gptq.sh"
  send_telegram "$alert" || true
  log "PARKED port=$port container=$name stop_result=$stop_result action=manual_recovery_required"
done
