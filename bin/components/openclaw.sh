#!/bin/zsh
# Agent防睡眠 — OpenClaw 组件
# 插电时运行 OpenClaw gateway，拔电时停止
# 定义 on_power_ac_openclaw / on_power_battery_openclaw 回调

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$PROJECT_DIR/logs"
STATE_DIR="$PROJECT_DIR/state"
GATEWAY_FAIL_FILE="$STATE_DIR/gateway-fail-count"
MANUAL_STOP_FLAG="$STATE_DIR/manual-stop.lock"

OPENCLAW_NODE="/opt/homebrew/opt/node/bin/node"
OPENCLAW_ENTRY="/opt/homebrew/lib/node_modules/openclaw/openclaw.mjs"
GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18801}"
GATEWAY_WATCHDOG_INTERVAL=3600  # 每小时检查一次

LAST_GATEWAY_WATCHDOG=0

_openclaw_log() {
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") openclaw: $*" >> "$LOG_DIR/openclaw.log"
}

_openclaw_gateway_running() {
  /usr/sbin/lsof -nP -iTCP:"$GATEWAY_PORT" -sTCP:LISTEN >/dev/null 2>&1
}

_openclaw_start() {
  if _openclaw_gateway_running; then
    return
  fi
  _openclaw_log "starting on AC power"
  rm -f "$MANUAL_STOP_FLAG"
  "$OPENCLAW_NODE" "$OPENCLAW_ENTRY" gateway install --port "$GATEWAY_PORT" --force >/dev/null 2>&1 || true
  "$OPENCLAW_NODE" "$OPENCLAW_ENTRY" gateway start >/dev/null 2>&1 &
  _openclaw_log "start command issued"
}

_openclaw_stop() {
  if ! _openclaw_gateway_running; then
    return
  fi
  _openclaw_log "stopping on battery"
  printf 'manual-stop %s\n' "$(date -Iseconds)" >| "$MANUAL_STOP_FLAG"
  "$OPENCLAW_NODE" "$OPENCLAW_ENTRY" gateway stop >/dev/null 2>&1 &
  _openclaw_log "stop command issued"
}

_openclaw_watchdog() {
  if ! on_ac_power 2>/dev/null; then
    rm -f "$GATEWAY_FAIL_FILE"
    return
  fi

  if _openclaw_gateway_running; then
    rm -f "$GATEWAY_FAIL_FILE"
    return
  fi

  local count=0
  if [ -f "$GATEWAY_FAIL_FILE" ]; then
    count="$(cat "$GATEWAY_FAIL_FILE" 2>/dev/null || echo 0)"
  fi
  count=$((count + 1))

  if [ "$count" -ge 3 ]; then
    _openclaw_log "watchdog: 3 failures reached, giving up until next power cycle"
    return
  fi

  printf "%s" "$count" > "$GATEWAY_FAIL_FILE"
  _openclaw_log "watchdog: gateway not running (attempt $count/3), restarting"
  rm -f "$MANUAL_STOP_FLAG"
  "$OPENCLAW_NODE" "$OPENCLAW_ENTRY" gateway install --port "$GATEWAY_PORT" --force >/dev/null 2>&1 || true
  "$OPENCLAW_NODE" "$OPENCLAW_ENTRY" gateway start >/dev/null 2>&1 &
  _openclaw_log "watchdog: restart command issued"
}

# === 回调函数（由 keepawake.sh 主循环调用） ===

on_power_ac_openclaw() {
  rm -f "$GATEWAY_FAIL_FILE"
  LAST_GATEWAY_WATCHDOG=0
  _openclaw_start
}

on_power_battery_openclaw() {
  _openclaw_stop
}

# 暴露给 keepawake.sh 主循环的心跳调用
openclaw_tick() {
  # 仅插电时每小时运行看门狗
  if ! on_ac_power 2>/dev/null; then
    return
  fi
  local now
  now="$(/bin/date +%s)"
  if [ $((now - LAST_GATEWAY_WATCHDOG)) -ge "$GATEWAY_WATCHDOG_INTERVAL" ]; then
    LAST_GATEWAY_WATCHDOG=$now
    _openclaw_watchdog
  fi
}
