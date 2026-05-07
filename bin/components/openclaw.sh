#!/bin/zsh
# Agent防睡眠 — OpenClaw 组件
# 插电时运行 OpenClaw gateway，拔电时停止
# 注意：此文件被 keepawake.sh source 加载，使用其 PROJECT_DIR 等变量

OC_LOG_DIR="$PROJECT_DIR/logs"
OC_STATE_DIR="$PROJECT_DIR/state"
OC_GATEWAY_FAIL_FILE="$OC_STATE_DIR/gateway-fail-count"
OC_MANUAL_STOP_FLAG="$OC_STATE_DIR/manual-stop.lock"

OPENCLAW_NODE="/opt/homebrew/opt/node/bin/node"
OPENCLAW_ENTRY="/opt/homebrew/lib/node_modules/openclaw/openclaw.mjs"
GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18801}"

OC_LAST_GATEWAY_WATCHDOG=0

_oc_log() {
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") openclaw: $*" >> "$OC_LOG_DIR/openclaw.log"
}

_oc_gateway_running() {
  /usr/sbin/lsof -nP -iTCP:"$GATEWAY_PORT" -sTCP:LISTEN >/dev/null 2>&1
}

_oc_start() {
  if _oc_gateway_running; then
    return
  fi
  _oc_log "starting on AC power"
  rm -f "$OC_MANUAL_STOP_FLAG"
  "$OPENCLAW_NODE" "$OPENCLAW_ENTRY" gateway install --port "$GATEWAY_PORT" --force >/dev/null 2>&1 || true
  "$OPENCLAW_NODE" "$OPENCLAW_ENTRY" gateway start >/dev/null 2>&1 &
  _oc_log "start command issued"
}

_oc_stop() {
  if ! _oc_gateway_running; then
    return
  fi
  _oc_log "stopping on battery"
  printf 'manual-stop %s\n' "$(date -Iseconds)" >| "$OC_MANUAL_STOP_FLAG"
  "$OPENCLAW_NODE" "$OPENCLAW_ENTRY" gateway stop >/dev/null 2>&1 &
  _oc_log "stop command issued"
}

_oc_watchdog() {
  if ! on_ac_power 2>/dev/null; then
    rm -f "$OC_GATEWAY_FAIL_FILE"
    return
  fi
  if _oc_gateway_running; then
    rm -f "$OC_GATEWAY_FAIL_FILE"
    return
  fi
  local count=0
  if [ -f "$OC_GATEWAY_FAIL_FILE" ]; then
    count="$(cat "$OC_GATEWAY_FAIL_FILE" 2>/dev/null || echo 0)"
  fi
  count=$((count + 1))
  if [ "$count" -ge 3 ]; then
    _oc_log "watchdog: 3 failures reached, giving up until next power cycle"
    return
  fi
  printf "%s" "$count" > "$OC_GATEWAY_FAIL_FILE"
  _oc_log "watchdog: gateway not running (attempt $count/3), restarting"
  rm -f "$OC_MANUAL_STOP_FLAG"
  "$OPENCLAW_NODE" "$OPENCLAW_ENTRY" gateway install --port "$GATEWAY_PORT" --force >/dev/null 2>&1 || true
  "$OPENCLAW_NODE" "$OPENCLAW_ENTRY" gateway start >/dev/null 2>&1 &
  _oc_log "watchdog: restart command issued"
}

# === 回调函数（由 keepawake.sh 主循环调用） ===
on_power_ac_openclaw() {
  rm -f "$OC_GATEWAY_FAIL_FILE"
  OC_LAST_GATEWAY_WATCHDOG=0
  _oc_start
}

on_power_battery_openclaw() {
  _oc_stop
}

openclaw_tick() {
  if ! on_ac_power 2>/dev/null; then
    return
  fi
  local now
  now="$(/bin/date +%s)"
  if [ $((now - OC_LAST_GATEWAY_WATCHDOG)) -ge 3600 ]; then
    OC_LAST_GATEWAY_WATCHDOG=$now
    _oc_watchdog
  fi
}
