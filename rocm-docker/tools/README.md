# tools/ —— 探针与保险丝

三个脚本 + 一个安装器。全部**不需要 root**（宿主机 `fiz` 在 `docker` 组里）。
所有日志默认写到共享目录 `~/Documents/project/ros2/memwatch/`
（就是容器内的 `/home/rocmUser/ros2/memwatch/`，方便你在容器里直接看）。

| 文件 | 作用 | 会不会杀东西 |
|---|---|---|
| `memwatch.py` | 核心探针。读 `/proc` 输出：内存曲线 / 线程数 top / **同命令重复份数 + 父进程 + 祖父进程** / RSS top | 不会 |
| `rocm_hog_watch.sh` | 每 N 秒调一次 `memwatch.py` 追加进日志 | 不会 |
| `rocm_guard.sh` | 保险丝：内存超阈值 → **先取证**（内存明细+线程+重复命令+RSS）→ `docker kill` | **会杀容器** |
| `install-units.sh` | 把上面两个装成 `systemd --user` 服务（开机/登录自启） | 不会 |

---

## 常用命令

```bash
# 只观察（诊断时的默认动作）
bash tools/rocm_hog_watch.sh            # 默认 5 秒
bash tools/rocm_hog_watch.sh 20         # 20 秒
tail -f ~/Documents/project/ros2/memwatch/rocm_hog.log

# 一次性体检（最适合"现在就看一眼"）
CG=/sys/fs/cgroup/system.slice/docker-$(docker inspect -f '{{.Id}}' rocm_dev).scope
python3 tools/memwatch.py $CG --report

# 保险丝
bash tools/rocm_guard.sh                          # 16G 触发
THRESHOLD=12 bash tools/rocm_guard.sh             # 更保守
DRY_RUN=1 THRESHOLD=2 bash tools/rocm_guard.sh     # 只取证不杀（演练）

# 常驻
bash tools/install-units.sh                       # guard 16G + watch 20s
systemctl --user status rocm-guard rocm-watch
systemctl --user stop rocm-guard                  # 跑大内存任务前临时关
```

## 环境变量

| 变量 | 默认 | 说明 |
|---|---|---|
| `NAME` | `rocm_dev` | 容器名 |
| `LOGDIR` | `~/Documents/project/ros2/memwatch` | 日志目录（共享目录，容器内可见） |
| `LOG` | `$LOGDIR/xxx.log` | 直接指定日志文件 |
| `THRESHOLD` | `16` | 保险丝触发阈值（GiB） |
| `INTERVAL` | guard `2` / watch `5` | 采样间隔（秒） |
| `DRY_RUN` | `0` | `1` = 只取证不杀 |

## 日志怎么读

```
23:14:54 cur=4.69G peak=5.27G anon=4.05G file=0.51G kern=0.12G tasks=451 | max=0 oom=0 oom_kill=0
         ↑当前    ↑历史峰值   ↑进程堆     ↑页缓存    ↑内核    ↑任务/线程数  ↑命中硬上限次数  ↑容器内被 OOM 杀过几次

--- 同命令重复份数 top 5（附父进程）---
   COUNT 1196 x <命令>          ← 上千份 = 进程风暴的元凶
            ↑ 1196 份 的父进程 pid=... <父命令>
            ↑↑ 祖父进程 pid=... <祖父命令>
```

判读经验：
- `tasks` 四位数且在涨 ⇒ 进程/线程风暴（本项目的经典症状）
- `file` 涨而 `anon` 平 ⇒ 页缓存被扫描灌满（大目录/搜索/索引）
- `oom_kill > 0` ⇒ 容器内部 OOM 真的杀了进程（只有在设了 `mem_limit` 时才可能）

## 注意

- 这些脚本读的是**宿主机 cgroupfs** 路径，只能在宿主机跑，容器里跑没意义。
- 容器被杀后 guard 会安静等待 cgroup 重新出现（`docker compose up -d` 后自动接上），
  不需要重启服务。
- 阈值不是越低越好：太低会误杀正常训练任务（RL 任务 10G+ 很正常）。
  16G 是"主机 31G、留 15G 余量"的折中。
