# Agent防睡眠

macOS 笔记本防睡眠 + 电源感知服务管理工具。

插电时保持唤醒、启动服务（如 OpenClaw）；拔电时停止非必要服务、省电；夜间 02:00-09:00 正常休眠。组件化设计，按需启用。

## 功能

- **电源感知**：插电 / 拔电自动切换行为
- **时段控制**：白天 09:00~凌晨01:59 防睡眠，凌晨 02:00~08:59 正常休眠
- **组件化**：每个受管服务是一个独立组件，可插拔
- **launchd 自启**：开机自动运行，崩溃自动重启
- **强制唤醒**：`force-awake` 标记可临时覆盖时段限制

## 组件

| 组件 | 功能 | 插电 | 拔电 |
|------|------|------|------|
| `openclaw` | OpenClaw gateway 启停 + 看门狗 | ✅ 启动 | ❌ 停止 |
| `cc` | cc-connect 保活 | ✅ 运行 | ✅ 运行 |

组件放在 `bin/components/` 目录下，核心引擎会自动加载。想禁用某个组件，删掉或移走对应的 `.sh` 文件即可。

## 安装

```bash
git clone https://github.com/sunyifeisb-art/agent-keepawake.git
cd agent-keepawake
chmod +x install.sh
./install.sh
```

默认安装到 `~/.agent-keepawake/`。指定目录：

```bash
./install.sh /自定义/路径
```

## 用法

```bash
# 强制唤醒（跳过 02:00-09:00 休眠时段）
touch ~/.agent-keepawake/state/force-awake

# 恢复时段控制
rm ~/.agent-keepawake/state/force-awake

# 查看日志
tail -f ~/.agent-keepawake/logs/keepawake.log
tail -f ~/.agent-keepawake/logs/openclaw.log
tail -f ~/.agent-keepawake/logs/cc.log
```

## 卸载

```bash
cd agent-keepawake
chmod +x uninstall.sh
./uninstall.sh
```

## 项目结构

```text
agent-keepawake/
├── bin/
│   ├── keepawake.sh              # 核心引擎
│   └── components/
│       ├── openclaw.sh           # OpenClaw 组件
│       └── cc.sh                 # cc-connect 组件
├── launchd/
│   └── local.agent-keepawake.plist.template
├── config/
├── logs/
├── state/
├── install.sh
├── uninstall.sh
├── LICENSE
└── README.md
```

## 依赖

- macOS（使用 `pmset`、`caffeinate`、`launchd`）
- `sudo` 免密执行 `pmset -a disablesleep`（安装脚本会配置）
- OpenClaw 组件依赖 Node.js（`/opt/homebrew/opt/node/bin/node`）
