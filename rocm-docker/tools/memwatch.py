#!/usr/bin/env python3
"""memwatch.py —— 直接读 /proc，给容器 cgroup 内的进程做体检。

输出：
  1. 内存曲线行
  2. 线程数 top（能看出是哪个进程在喷线程）
  3. 同一命令行重复份数 top（能看出是哪个命令在被反复拉起）+ 它的父进程是谁
  4. RSS top

用法:
  python3 memwatch.py /sys/fs/cgroup/system.slice/docker-xxx.scope
  python3 memwatch.py <cgroup> --report      # 详细报告（guard 触发时用）
"""
import os
import sys
import time
from collections import Counter, defaultdict

def g(n):
    return f"{n / 1073741824:.2f}G"

def read_kv(path):
    out = {}
    try:
        with open(path) as f:
            for line in f:
                a = line.split(None, 1)
                if len(a) == 2:
                    out[a[0].rstrip(":")] = a[1].strip()
    except OSError:
        pass
    return out

def read_int(path):
    try:
        with open(path) as f:
            return int(f.read().strip())
    except (OSError, ValueError):
        return 0

def proc_info(pid):
    """返回 (ppid, threads, rss_bytes, cmd)"""
    ppid = 0
    try:
        with open(f"/proc/{pid}/stat", "rb") as f:
            data = f.read()
        # comm 里可能有空格/括号，从最后一个 ')' 之后开始切
        rest = data[data.rfind(b")") + 2:].split()
        ppid = int(rest[1])
    except (OSError, IndexError, ValueError):
        pass
    st = read_kv(f"/proc/{pid}/status")
    try:
        threads = int(st.get("Threads", 0))
    except ValueError:
        threads = 0
    try:
        rss = int(st.get("VmRSS", "0 kB").split()[0]) * 1024
    except (ValueError, IndexError):
        rss = 0
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            cmd = f.read().replace(b"\0", b" ").decode(errors="replace").strip()
    except OSError:
        cmd = ""
    return ppid, threads, rss, cmd

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    cg = sys.argv[1].rstrip("/")
    report = "--report" in sys.argv

    mem = read_kv(f"{cg}/memory.stat")
    cur = read_int(f"{cg}/memory.current")
    peak = read_int(f"{cg}/memory.peak")
    tasks = read_int(f"{cg}/pids.current")
    ev = read_kv(f"{cg}/memory.events")
    print(
        f"cur={g(cur)} peak={g(peak)} anon={g(int(mem.get('anon', 0)))} "
        f"file={g(int(mem.get('file', 0)))} kern={g(int(mem.get('kernel', 0)))} "
        f"tasks={tasks} | "
        + " ".join(f"{k}={v}" for k, v in ev.items())
    )

    pids = []
    try:
        with open(f"{cg}/cgroup.procs") as f:
            pids = [int(x) for x in f.read().split()]
    except OSError:
        return 0

    info = {}
    for pid in pids:
        ppid, th, rss, cmd = proc_info(pid)
        info[pid] = (ppid, th, rss, cmd)

    parent_cmd = lambda pid: (info.get(pid) or (0, 0, 0, ""))[3][:90] or "?"

    print("--- 线程数 top 5 ---")
    for pid, (ppid, th, rss, cmd) in sorted(info.items(), key=lambda kv: -kv[1][1])[:5]:
        print(f"   THREADS {th:<5} pid={pid:<8} ppid={ppid:<8} rss={g(rss):>6}  {cmd[:100]}")

    groups = defaultdict(list)
    for pid, (ppid, th, rss, cmd) in info.items():
        groups[cmd].append((pid, ppid))
    print("--- 同命令重复份数 top 5（附父进程）---")
    for cmd, members in sorted(groups.items(), key=lambda kv: -len(kv[1]))[:5]:
        parents = Counter(pp for _, pp in members)
        print(f"   COUNT {len(members):<5} x  {cmd[:230]}")
        for pp, n in parents.most_common(3):
            print(f"            ↑ {n} 份 的父进程 pid={pp}  {parent_cmd(pp)}")
        top_pp = parents.most_common(1)[0][0]
        gp = (info.get(top_pp) or (0, 0, 0, ""))[0]
        print(f"            ↑↑ 祖父进程 pid={gp}  {parent_cmd(gp)}")

    if report:
        print("--- RSS top 8 ---")
        for pid, (ppid, th, rss, cmd) in sorted(info.items(), key=lambda kv: -kv[1][2])[:8]:
            print(f"   RSS {g(rss):>6} threads={th:<4} pid={pid:<8} ppid={ppid:<8} {cmd[:100]}")
        print(f"--- 进程/线程总数: {len(info)} 个进程 / {tasks} 个任务 ---")
    return 0

if __name__ == "__main__":
    sys.exit(main())
