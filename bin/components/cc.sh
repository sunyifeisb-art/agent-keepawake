#!/bin/zsh
# Agent防睡眠 — cc-connect 组件
# 保持 cc-connect 始终运行，独立于电源状态
# 定义 on_power_ac_cc / on_power_battery_cc 回调

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$PROJECT_DIR/logs"
STATE_DIR="$PROJECT_DIR/state"

CC_CONNECT_BIN="/opt/homebrew/bin/cc-connect"

_cc_log() {
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") cc: $*" >> "$LOG_DIR/cc.log"
}

_cc_running() {
  pgrep -f "cc-connect-inline" >/dev/null 2>&1
}

_cc_ensure_running() {
  if _cc_running; then
    return
  fi
  _cc_log "not running, starting"
  "$CC_CONNECT_BIN" start >/dev/null 2>&1 &
  _cc_log "start command issued"
}

_cc_stop() {
  if ! _cc_running; then
    return
  fi
  _cc_log "stopping"
  pkill -f "cc-connect start" 2>/dev/null || true
  _cc_log "stop command issued"
}

# === 回调函数（由 keepawake.sh 主循环调用） ===

on_power_ac_cc() {
  # 插电：确保 cc-connect 运行（通常已经在跑）
  _cc_ensure_running
}

on_power_battery_cc() {
  # 拔电：cc-connect 继续运行，不做特殊处理
  _cc_ensure_running
}

# 暴露给 keepawake.sh 主循环的心跳调用
cc_tick() {
  _cc_ensure_running
}
