#!/bin/zsh
# Agent防睡眠 — 卸载脚本
set -euo pipefail

INSTALL_DIR="${1:-$HOME/.agent-keepawake}"
PLIST_LABEL="local.agent-keepawake"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"

echo "==> Agent防睡眠 卸载"
echo ""

# 1. 卸载 launchd 服务
echo "==> 停止并卸载 launchd 服务"
launchctl bootout "gui/$(id -u)/$PLIST_LABEL" 2>/dev/null && echo "    服务已停止" || echo "    服务未运行"
rm -f "$PLIST_DEST"

# 2. 恢复合盖睡眠
echo "==> 恢复系统合盖睡眠设置"
sudo -n /usr/bin/pmset -a disablesleep 0 2>/dev/null && echo "    已恢复" || echo "    请手动执行: sudo pmset -a disablesleep 0"

# 3. 询问是否删除文件
echo ""
echo "==> 文件目录: $INSTALL_DIR"
echo -n "是否删除所有文件？(y/N): "
read -r REPLY
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
  rm -rf "$INSTALL_DIR"
  echo "    已删除"
else
  echo "    保留: $INSTALL_DIR"
fi

echo "==> 卸载完成"
