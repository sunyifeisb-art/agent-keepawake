#!/bin/zsh
# Agent防睡眠 — cc-connect 组件
# 保持 cc-connect 始终运行，独立于电源状态
# 注意：此文件被 keepawake.sh source 加载，使用其 PROJECT_DIR 等变量

CC_LOG_DIR="$PROJECT_DIR/logs"
CC_CONNECT_BIN="/opt/homebrew/bin/cc-connect"

_cc_log() {
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") cc: $*" >> "$CC_LOG_DIR/cc.log"
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

# === 回调函数（由 keepawake.sh 主循环调用） ===
on_power_ac_cc() {
  _cc_ensure_running
}

on_power_battery_cc() {
  _cc_ensure_running
}

cc_tick() {
  _cc_ensure_running
}
