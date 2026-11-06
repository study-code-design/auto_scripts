#!/usr/bin/env bash
# rocm_guard.sh —— rocm_dev 容器的"保险丝 + 现场取证"
#
#  1) 每 INTERVAL 秒看一次容器 cgroup 的内存；超过 THRESHOLD(GiB) 时：
#       先把现场写进 rocm_guard.log（内存明细 / 线程数 top / RSS top /
#       同一命令被拉起多少份），再 docker kill 容器。
#  2) 宿主此时通常还有十几 G 空闲，不会卡死。
#
# 不需要 root。用法：
#   bash rocm_guard.sh                        # 默认 16 GiB
#   THRESHOLD=12 bash rocm_guard.sh
#   DRY_RUN=1 THRESHOLD=2 bash rocm_guard.sh  # 只取证不杀
#
# 日志: 与本脚本同目录 rocm_guard.log（可用 LOG=/path 覆盖）

set -u
NAME="${NAME:-rocm_dev}"
THRESHOLD="${THRESHOLD:-16}"
INTERVAL="${INTERVAL:-2}"
DRY_RUN="${DRY_RUN:-0}"
LOGDIR="${LOGDIR:-$HOME/Documents/project/ros2/memwatch}"   # 共享目录：容器内 /home/rocmUser/ros2/memwatch
mkdir -p "$LOGDIR"
LOG="${LOG:-$LOGDIR/rocm_guard.log}"
LIMIT_BYTES=$(awk -v g="$THRESHOLD" 'BEGIN{printf "%.0f", g*1073741824}')

g()  { awk -v v="${1:-0}" 'BEGIN{printf "%.2f", v/1073741824}'; }
log(){ printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }

CID=$(docker inspect -f '{{.Id}}' "$NAME" 2>/dev/null) || { echo "找不到容器 $NAME"; exit 1; }
CG="/sys/fs/cgroup/system.slice/docker-${CID}.scope"
# 容器被杀后 cgroup 会消失：安静等待它回来（或新容器起来）
while [ ! -r "$CG/memory.current" ]; do
  sleep 5
  CID=$(docker inspect -f '{{.Id}}' "$NAME" 2>/dev/null) || continue
  CG="/sys/fs/cgroup/system.slice/docker-${CID}.scope"
done

log "==== guard 启动 阈值=$(g "$LIMIT_BYTES")G dry_run=$DRY_RUN cgroup=$CG"
echo "守卫中：阈值 ${THRESHOLD}GiB / ${INTERVAL}s。日志：$LOG"

# 列出属于本 cgroup 的进程里，某字段 top N
top_by() {  # $1=字段列号(2=nlwp,3=rss)  $2=N
  ps -e -o pid,nlwp,rss,args 2>/dev/null | awk -v L="$LIST" -v c="$1" '
    BEGIN{n=split(L,a,","); for(i=1;i<=n;i++) if(a[i]!="") M[a[i]]=1}
    NR>1 && ($1 in M)' | sort -k"$1" -rn | head -"$2"
}

trap 'echo; log "guard 停止（未触发）"; exit 0' INT TERM
tick=0
while :; do
  if [ $((tick % 30)) -eq 0 ] && [ $tick -gt 0 ]; then   # 每 ~60s 刷新容器 ID
    NEW=$(docker inspect -f '{{.Id}}' "$NAME" 2>/dev/null) || true
    if [ -n "${NEW:-}" ] && [ "$NEW" != "$CID" ]; then
      CID="$NEW"; CG="/sys/fs/cgroup/system.slice/docker-${CID}.scope"
      log "容器已重建，跟踪新 cgroup"
    fi
  fi
  tick=$((tick+1))

  CUR=$(cat "$CG/memory.current" 2>/dev/null || echo 0)
  TASKS=$(cat "$CG/pids.current" 2>/dev/null || echo 0)
  LIST=$(tr '\n' ',' < "$CG/cgroup.procs" 2>/dev/null)

  if [ "${CUR:-0}" -gt "$LIMIT_BYTES" ]; then
    log "==================== 触发！cur=$(g "$CUR")G > 阈值 $(g "$LIMIT_BYTES")G  tasks=$TASKS ===================="
    log "memory.stat(关键项): anon=$(g "$(awk '/^anon /{print $2}' "$CG/memory.stat")")G file=$(g "$(awk '/^file /{print $2}' "$CG/memory.stat")")G kernel=$(g "$(awk '/^kernel /{print $2}' "$CG/memory.stat")")G kernel_stack=$(g "$(awk '/^kernel_stack /{print $2}' "$CG/memory.stat")")G pagetables=$(g "$(awk '/^pagetables /{print $2}' "$CG/memory.stat")")G"
    log "memory.events: $(awk '{printf "%s=%s ", $1, $2}' "$CG/memory.events")"

    log "--- 线程数 top 8（fork/thread 风暴的话，第一名就是它）---"
    top_by 2 8 | while read -r pid nlwp rss args; do
      log "    THREADS $nlwp  pid=$pid  ${args:0:120}"
    done

    log "--- 同一命令行被拉起多少份（按数量 top 8）---"
    ps -e -o pid,args 2>/dev/null | awk -v L="$LIST" '
      BEGIN{n=split(L,a,","); for(i=1;i<=n;i++) if(a[i]!="") M[a[i]]=1}
      NR>1 && ($1 in M){ $1=""; sub(/^ /,""); c[$0]++ }
      END{for(k in c) printf "%d\t%s\n", c[k], k}' | sort -rn | head -8 |
      while IFS=$'\t' read -r c args; do
        log "    COUNT   $c x  ${args:0:120}"
      done

    log "--- RSS top 8 ---"
    top_by 3 8 | while read -r pid nlwp rss args; do
      log "    RSS     $(g "$((rss*1024))")G  threads=$nlwp  pid=$pid  ${args:0:120}"
    done

    if [ "$DRY_RUN" = "1" ]; then
      log "DRY_RUN：不杀，90 秒后重新判断"
      sleep 90
      continue
    fi
    log ">>> docker kill $NAME"
    docker kill "$NAME" >> "$LOG" 2>&1
    log ">>> 已杀。宿主 free: $(free -h | awk '/内存|Mem/{print $3"/"$2}')"
    echo "已触发保险丝：容器被杀，现场见 $LOG"
    exit 0
  fi

  # 心跳（任务数一多就每 30 秒记一条，方便看爬升速度）
  if [ $((tick % 15)) -eq 0 ] && [ "${CUR:-0}" -gt 536870912 ]; then
    log "heartbeat cur=$(g "$CUR")G tasks=$TASKS anon=$(g "$(awk '/^anon /{print $2}' "$CG/memory.stat")")G top_threads: $(top_by 2 1 | awk '{printf "%s threads pid=%s %s", $2, $1, $4}')"
  fi

  sleep "$INTERVAL"
done
