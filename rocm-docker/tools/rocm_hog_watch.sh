#!/usr/bin/env bash
# rocm_hog_watch.sh —— 只观察不动手。每 N 秒调 memwatch.py 采样一次容器内的进程结构。
# 重点：同一命令被重复拉起多少份，以及它的【父进程】是谁 —— 用来钉死"谁在喷进程"。
#
# 用法: bash rocm_hog_watch.sh [间隔秒, 默认5]
# 日志: 与本脚本同目录 rocm_hog.log（可用 LOG=/path 覆盖）

set -u
NAME="${NAME:-rocm_dev}"
INTERVAL="${1:-5}"
HERE="$(cd "$(dirname "$0")" && pwd)"
LOGDIR="${LOGDIR:-$HOME/Documents/project/ros2/memwatch}"   # 共享目录：容器内 /home/rocmUser/ros2/memwatch
mkdir -p "$LOGDIR"
LOG="${LOG:-$LOGDIR/rocm_hog.log}"

CID=$(docker inspect -f '{{.Id}}' "$NAME" 2>/dev/null) || { echo "找不到容器 $NAME"; exit 1; }
CG="/sys/fs/cgroup/system.slice/docker-${CID}.scope"

echo "# 采样开始 $(date '+%F %T') interval=${INTERVAL}s" >> "$LOG"

while :; do
  if [ -r "$CG/memory.current" ]; then
    python3 "$HERE/memwatch.py" "$CG" 2>/dev/null | while IFS= read -r line; do
      printf '%s %s\n' "$(date '+%H:%M:%S')" "$line" >> "$LOG"
    done
  fi
  sleep "$INTERVAL"
done
