#!/bin/zsh
# Agent防睡眠 — 安装脚本
set -euo pipefail

INSTALL_DIR="${1:-$HOME/.agent-keepawake}"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_LABEL="local.agent-keepawake"
PLIST_DEST="$LAUNCH_AGENTS_DIR/$PLIST_LABEL.plist"

echo "==> Agent防睡眠 安装"
echo "    目标目录: $INSTALL_DIR"
echo ""

# 1. 复制文件
echo "==> 复制文件到 $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"/{bin/components,launchd,logs,state,config}
cp -R "$(dirname "$0")/bin" "$INSTALL_DIR/"
cp -R "$(dirname "$0")/config" "$INSTALL_DIR/" 2>/dev/null || true
chmod +x "$INSTALL_DIR/bin/keepawake.sh"
chmod +x "$INSTALL_DIR/bin/components/"*.sh 2>/dev/null || true

# 2. 安装 launchd plist
echo "==> 安装 launchd 自启服务"
mkdir -p "$LAUNCH_AGENTS_DIR"
sed "s|__INSTALL_DIR__|$INSTALL_DIR|g" "$(dirname "$0")/launchd/local.agent-keepawake.plist.template" > "$PLIST_DEST"

# 3. 卸载旧服务（如果存在）
launchctl bootout "gui/$(id -u)/$PLIST_LABEL" 2>/dev/null || true
sleep 1

# 4. 加载新服务
launchctl bootstrap "gui/$(id -u)" "$PLIST_DEST" 2>/dev/null || launchctl kickstart "gui/$(id -u)/$PLIST_LABEL" 2>/dev/null || true

echo ""
echo "==> 验证"
sleep 1
if launchctl print "gui/$(id -u)/$PLIST_LABEL" 2>/dev/null | grep -q "state = running"; then
  echo "✅ agent-keepawake 已启动运行"
else
  echo "⚠️  服务状态异常，请检查日志: $INSTALL_DIR/logs/"
fi

echo "==> 安装完成"
echo ""
echo "常用命令:"
echo "  sudo pmset -a disablesleep 1   # 手动禁用合盖睡眠"
echo "  touch $INSTALL_DIR/state/force-awake  # 强制保持唤醒（跳过时段限制）"
echo "  rm $INSTALL_DIR/state/force-awake     # 恢复时段控制"
echo ""
echo "查看日志:"
echo "  tail -f $INSTALL_DIR/logs/keepawake.log"
