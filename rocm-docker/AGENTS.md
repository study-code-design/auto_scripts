# AGENTS.md —— 给接手这个目录的 Agent

这个目录是 **ROCm 开发容器 `rocm_dev` 的编排与运维目录**。
2026-11 这里发生过一次"容器把整机拖死"的严重故障，现已定位并修复。

---

## 0. 先读这四份，按顺序，别跳

| 顺序 | 文件 | 你会得到什么 |
|---|---|---|
| 1 | `docs/01-症状与排查记录.md` | 用户症状、7 条关键证据原文、**5 个被推翻的假设**（别重走） |
| 2 | `docs/02-三层根因与修复.md` | 三层根因、每层的修法与验证命令、实测对比数字 |
| 3 | `docs/03-排查手册.md` | 复发时按步骤做的操作手册、判读表、临时取证脚本 |
| 4 | `docs/04-改动总表.md` | **一页表格**：8 项改动 × 文件 / 改了什么 / 原因 / 解决办法 / 验证命令 / 现状 |
| 5 | `CHANGELOG-2026-11.md` | 这次到底改了哪些文件、diff 级说明、修复前后对比 |

代码只有三个文件，都在 `tools/`，读 `tools/README.md` 即可。

**一句话结论**：主因是 **VS Code 的 Dev Containers 自动端口转发 + `network_mode: host`
自激**，在容器里每秒 fork 一个永不退出的 `node -e` 桥 → 1200 孤儿进程 / 14G / 8400 tasks。
不是容器镜像的问题，也不是 ROCm/显存问题。

---

## 0.5 换机器 / 多机同步后必检清单（已踩过两次坑）

本目录的配置里有**机器相关项**：仓库是同一份，但每台机器的用户名/路径/socket 不一样。
换机器、重装系统或拉完仓库后，**逐项检查，不存在就改成该机的真实值**：

| # | 机器相关项 | 检查什么 | tu 机器（2026-11-11）的正确值 |
|---|---|---|---|
| 1 | `rocm-docker/.env` 的 `WORKSPACE` | **路径必须真实存在且非空**。不存在时 Docker 会静默创建一个空目录挂进去，容器里看不到任何文件，极易误判成别的问题 | `/home/tu/Documents/cpp_project/rl_rocm`（70G） |
| 2 | 宿主 `~/.config/Code/User/settings.json` | `"remote.autoForwardPorts": false` + `"remote.restoreForwardedPorts": false` —— **不在仓库里**，每台机器要手动加；漏掉 = 主因复发 | 已加（2026-11-11 补） |
| 3 | `rocm-docker/.env` 的 `WAYLAND_DISPLAY` | 宿主实际 socket 名：`ls /run/user/1000 \| grep wayland` | `wayland-1` |
| 4 | `rocm-docker/.env` 的 `DISPLAY` | `echo $DISPLAY`（X11 环境才需要） | `:0` |
| 5 | 文档里的绝对路径 | 本目录 docs / AGENTS.md 历史记录里写的 `/home/fiz/...` 是旧机器的路径，读文档时**自行替换成当前机器的 `$WORKSPACE`** | — |

**验证命令（重建容器后跑一遍）**：

```bash
docker exec rocm_dev bash -lc 'ls /home/rocmUser/ros2 \| head -3; touch /home/rocmUser/ros2/_wtest && rm /home/rocmUser/ros2/_wtest && echo 可写✔'
docker inspect rocm_dev --format 'Memory={{.HostConfig.Memory}}'   # 应为 25769803776 (24G)
grep autoForwardPorts ~/.config/Code/User/settings.json            # 应为 false
```

> 2026-11-11 实录：tu 机器上 ①② 同时缺失 → 11-06 故障完整复发。
> ① 导致容器共享目录是空壳，② 导致转发自激循环再次把内存吃爆。

---

## 1. 文件地图

```
rocm-docker/
├── AGENTS.md                 ← 你正在读
├── docker-compose.yml        ← 编排（内存上限、runtime 目录挂载、GPU/输入设备、host 网络）
├── Dockerfile / Dockerfile.dev
├── .env                      ← IMAGE_NAME / WORKSPACE / DISPLAY / WAYLAND_DISPLAY
│                               （WORKSPACE 等是机器相关项，见 0.5 节）
├── CHANGELOG-2026-11.md      ← 本次改动清单
├── docs/
│   ├── 01-症状与排查记录.md
│   ├── 02-三层根因与修复.md
│   ├── 03-排查手册.md
│   └── 04-改动总表.md        ← 一页表格：改了什么/为什么/怎么解决/怎么验证
└── tools/
    ├── memwatch.py           ← 读 /proc 输出内存/线程/重复命令/父子链（核心探针）
    ├── rocm_hog_watch.sh     ← 只记录：每 N 秒调 memwatch.py
    ├── rocm_guard.sh         ← 保险丝：超阈值先取证再 docker kill
    ├── install-units.sh      ← 装两个 systemd --user 服务（不需要 root）
    └── README.md
```

日志（运行期产生，不在本目录，放在共享工作区里以便容器内也能读）：

```
宿主机  $WORKSPACE/memwatch/rocm_hog.log      ← 即容器内 /home/rocmUser/ros2/memwatch/
        $WORKSPACE/memwatch/rocm_guard.log
        tu 机器 = /home/tu/Documents/cpp_project/rl_rocm/memwatch/
```

> 放共享目录（`$WORKSPACE`）是为了让容器内也能 `cat`，
> **代码留在本目录**，脚本用 `LOGDIR` 环境变量指向共享目录。

---

## 2. 标准工作流（按顺序）

```bash
cd ~/Documents/auto_scripts/rocm-docker

# ① 改配置后重建镜像（注意：compose build 会被 buildx 拦）
cd .. && docker build -f rocm-docker/Dockerfile.dev -t rocm6-4_ub22:latest . && cd rocm-docker

# ② 起容器
docker compose up -d

# ③ 装上探针与保险丝（幂等，随时可重跑）
bash tools/install-units.sh                 # 默认 guard=16G / watch=20s
THRESHOLD=20 bash tools/install-units.sh    # 要跑大任务时临时放宽

# ④ 验证三层修复都还在（全部应通过）
cat /sys/fs/cgroup/system.slice/docker-$(docker inspect -f '{{.Id}}' rocm_dev).scope/memory.max
docker exec rocm_dev bash -lc 'touch /run/user/1000/_p && echo ipc-ok && rm -f /run/user/1000/_p'
grep -E 'autoForwardPorts|restoreForwardedPorts' ~/.config/Code/User/settings.json

# ⑤ 观察曲线（打开 VS Code 连容器后看）
grep 'cur=' $WORKSPACE/memwatch/rocm_hog.log | tail -10
```

**健康基线**（两个 VS Code 窗口同时开）：`cur ≈ 4~5G`、`tasks ≈ 400~500`、
`node -e` 隧道个位数且不增长、`peak < 8G`。

---

## 3. 允许改 / 禁止改

**可以改**
- `docker-compose.yml`：内存上限、挂载、env
- `Dockerfile.dev`：镜像层（注意 `/home/rocmUser` 是 volume，写进去的东西会被遮蔽）
- `tools/*`：探针与保险丝逻辑
- 宿主 VS Code 用户设置 `~/.config/Code/User/settings.json`（只加法，别删别人的键）
- 容器内 `~/.vscode-server/data/Machine/settings.json` 的排除规则

**不要动**
- `network_mode: host`：ROS2 / GUI / DDS 都要它。**要治的是转发，不是网络模式**
- `~/.cache/uv`（20G）、`~/ros2`（57G）里的用户数据，别清理
- 日志目录结构（容器内要用）

## 4. 常见误判（血泪）

1. **别一上来查显存**：`mem_info_vram_used` 只有 100MB 量级，问题是主机内存。
2. **别看到 `ExitCode=137` 就写"OOM"**：先看 `OOMKilled`，`false` 说明是
   `systemd-oomd` 的整组杀；再 `journalctl -b 0 | grep oomd`。
3. **别只看 RSS top**：进程风暴里每个进程只有 2~3MB，RSS 前 5 名加起来才 2G，
   要看 `pids.current` 和 **同一命令行重复份数**。
4. **别把 Fitten Code 的 `tokenExpired` 刷屏当元凶**：那是噪声。
5. **收紧内存上限会掩盖症状但会制造新症状**（抖动→整机卡死）。必须同时解决第 3 层。
6. **`docker compose build` 在本机必失败**（`network: host` 需要 `--allow=network.host`），
   用 `docker build` 直接构建。

## 5. 复发时的最短路径

```bash
# 正在涨？先看是不是同一症状（30 秒）
CG=/sys/fs/cgroup/system.slice/docker-$(docker inspect -f '{{.Id}}' rocm_dev).scope
cat $CG/pids.current; grep 'node -e' $WORKSPACE/memwatch/rocm_hog.log | tail -2

# 是同一症状（tasks 四位数 + node -e 成百上千）
grep -n 'autoForwardPorts' ~/.config/Code/User/settings.json   # 被改回 true 了？
# 修好后重启窗口（Reload Window），不用重建容器

# 不是同一症状 → 走 docs/03-排查手册.md 第 0→1→2→3 步
```
