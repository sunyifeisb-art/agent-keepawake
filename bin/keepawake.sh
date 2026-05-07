#!/bin/zsh
# Agent防睡眠 — 核心引擎
# 电源检测 + caffeinate + 时段调度
# 自动加载 bin/ 下的组件模块（openclaw.sh / cc.sh 等）

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" || exit 1
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)" || exit 1
readonly SCRIPT_DIR PROJECT_DIR
LOG_DIR="$PROJECT_DIR/logs"
STATE_DIR="$PROJECT_DIR/state"
FORCE_AWAKE_FLAG="$STATE_DIR/force-awake"

mkdir -p "$LOG_DIR" "$STATE_DIR"

CAFFEINATE_PID=""
LID_SLEEP_ACTIVE=false

cleanup() {
  log "agent-keepawake: stopping"
  stop_caffeinate
  enable_lid_sleep
  exit 0
}
trap cleanup EXIT INT TERM

log() {
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") $*" >> "$LOG_DIR/keepawake.log"
}

on_ac_power() {
  /usr/bin/pmset -g batt 2>/dev/null | /usr/bin/grep -q "AC Power"
}

# === 防睡眠控制 ===

is_awake_hours() {
  if [ -f "$FORCE_AWAKE_FLAG" ]; then
    return 0
  fi
  local hour
  hour="$(/bin/date +%H)"
  # 白天 09:00~凌晨01:59 → 防睡眠（电脑保持唤醒）
  # 凌晨 02:00~08:59     → 正常休眠（电脑可睡眠）
  [ "$hour" -ge 9 ] || [ "$hour" -lt 2 ]
}

start_caffeinate() {
  if [ -n "$CAFFEINATE_PID" ] && kill -0 "$CAFFEINATE_PID" 2>/dev/null; then
    return
  fi
  /usr/bin/caffeinate -s -i -d -w $$ >/dev/null 2>&1 &
  CAFFEINATE_PID=$!
  log "caffeinate started (pid=$CAFFEINATE_PID)"
}

stop_caffeinate() {
  if [ -n "$CAFFEINATE_PID" ] && kill -0 "$CAFFEINATE_PID" 2>/dev/null; then
    kill "$CAFFEINATE_PID" 2>/dev/null || true
    wait "$CAFFEINATE_PID" 2>/dev/null || true
    log "caffeinate stopped"
  fi
  CAFFEINATE_PID=""
}

enable_lid_sleep() {
  if [ "$LID_SLEEP_ACTIVE" = true ]; then
    sudo -n /usr/bin/pmset -a disablesleep 0 2>/dev/null
    LID_SLEEP_ACTIVE=false
    log "lid sleep re-enabled (normal sleep)"
  fi
}

disable_lid_sleep() {
  if [ "$LID_SLEEP_ACTIVE" = false ]; then
    sudo -n /usr/bin/pmset -a disablesleep 1 2>/dev/null
    LID_SLEEP_ACTIVE=true
    log "lid sleep disabled (keep awake)"
  fi
}

# === 加载组件模块 ===

# 每个组件应定义 on_power_ac() 和 on_power_battery() 回调
# 由 keepawake 核心在电源切换时调用
COMPONENT_DIR="$SCRIPT_DIR/components"
COMPONENTS=()

if [ -d "$COMPONENT_DIR" ]; then
  for comp in "$COMPONENT_DIR"/*.sh; do
    [ -f "$comp" ] || continue
    source "$comp"
    COMPONENTS+=("$(basename "$comp" .sh)")
    log "component loaded: $(basename "$comp" .sh)"
  done
fi

# === 主循环 ===

log "agent-keepawake: starting"

STATE=""
POWER_STATE=""

while true; do
  # 电源检测 & 通知组件
  if on_ac_power; then
    if [ "$POWER_STATE" != "ac" ]; then
      POWER_STATE="ac"
      log "power: switched to AC"
      for comp in $COMPONENTS; do
        "on_power_ac_$comp" 2>/dev/null || true
      done
    fi
  else
    if [ "$POWER_STATE" != "battery" ]; then
      POWER_STATE="battery"
      log "power: switched to battery"
      for comp in $COMPONENTS; do
        "on_power_battery_$comp" 2>/dev/null || true
      done
    fi
  fi

  # 时段防睡眠
  if is_awake_hours; then
    if [ "$STATE" != "awake" ]; then
      STATE="awake"
      log "enter awake hours (day 09:00~night 01:59, keep awake)"
    fi
    disable_lid_sleep
    start_caffeinate
  else
    if [ "$STATE" != "sleep" ]; then
      STATE="sleep"
      log "enter sleep hours (early morning 02:00-08:59, allow sleep)"
    fi
    stop_caffeinate
    enable_lid_sleep
  fi

  # 组件心跳（看门狗等定时任务）
  for comp in $COMPONENTS; do
    "${comp}_tick" 2>/dev/null || true
  done

  sleep 60
done
