#!/usr/bin/env bash
# install-units.sh —— 安装/更新两个 systemd 用户服务（不需要 root）
#
#   rocm-watch.service  每 20 秒采样容器进程结构（只记录，不动手）
#   rocm-guard.service  内存超过 THRESHOLD(GiB) 时先取证再 docker kill 容器
#
# 用法:
#   bash tools/install-units.sh                 # 默认 guard 阈值 16G
#   THRESHOLD=20 bash tools/install-units.sh    # 自定义阈值
#
# 卸载:
#   systemctl --user disable --now rocm-guard rocm-watch
#   rm ~/.config/systemd/user/rocm-{guard,watch}.service
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
THRESHOLD="${THRESHOLD:-16}"
INTERVAL="${INTERVAL:-20}"
UNITDIR="$HOME/.config/systemd/user"
mkdir -p "$UNITDIR"

cat > "$UNITDIR/rocm-guard.service" <<EOF
[Unit]
Description=rocm_dev 容器内存保险丝（超阈值 docker kill + 存证据）
After=default.target

[Service]
Type=simple
Environment=THRESHOLD=$THRESHOLD
Environment=INTERVAL=2
ExecStart=/bin/bash $HERE/rocm_guard.sh
Restart=always
RestartSec=15
TimeoutStopSec=5

[Install]
WantedBy=default.target
EOF

cat > "$UNITDIR/rocm-watch.service" <<EOF
[Unit]
Description=rocm_dev 逐进程内存/线程/读盘监视（只记录，不杀）
After=default.target

[Service]
Type=simple
ExecStart=/bin/bash $HERE/rocm_hog_watch.sh $INTERVAL
Restart=always
RestartSec=10
TimeoutStopSec=5

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now rocm-guard rocm-watch
systemctl --user restart rocm-guard rocm-watch

echo "已安装："
echo "  guard  阈值 ${THRESHOLD}GiB   -> $HERE/rocm_guard.sh"
echo "  watch  每 ${INTERVAL}s 采样    -> $HERE/rocm_hog_watch.sh"
echo "  日志目录 -> $HOME/Documents/project/ros2/memwatch/  (容器内 /home/rocmUser/ros2/memwatch/)"
systemctl --user --no-pager --lines=0 status rocm-guard rocm-watch || true
