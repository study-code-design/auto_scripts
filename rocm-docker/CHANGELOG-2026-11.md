# CHANGELOG · 2026-11（"容器把整机拖死"故障）

时间：2026-11-03 首次出现 → 2026-11-06 定位并修复完成
故障摘要：见 `docs/01-症状与排查记录.md`；根因：见 `docs/02-三层根因与修复.md`

改动共 **8 处**，分三类。

---

## A. 容器编排（本目录）

### 1. `docker-compose.yml` —— 加内存上限

```diff
     shm_size: 12g
     network_mode: host
+
+    # 没有上限时容器可吃光整机 31G RAM + 31G zram swap，触发 systemd-oomd
+    # 的 SwapUsedLimit=90% 规则，一次性杀掉整个 cgroup 的 1 万多个进程
+    mem_limit: 24g
+    memswap_limit: 24g      # 相等 = 不给容器 swap
```

### 2. `docker-compose.yml` —— 修 `/run/user/1000` 挂载

```diff
     volumes:
       - /tmp/.X11-unix:/tmp/.X11-unix:rw
-      - ${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY:-wayland-0}:${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY:-wayland-0}:rw
+      # 只挂单个 socket 时容器内 /run/user/1000 是 root:root 0755，
+      # VS Code 建 vscode-ipc-*.sock 报 EACCES，Agent Host 无限重启
+      - ${XDG_RUNTIME_DIR:-/run/user/1000}:/run/user/1000:rw
```

### 3. `.env` —— wayland socket 名修正

```diff
-WAYLAND_DISPLAY=wayland-0
+WAYLAND_DISPLAY=wayland-1        # 宿主实际 socket 名（ls /run/user/1000 | grep wayland）
```

### 4. `Dockerfile.dev` —— 注释掉无效的 zoxide 层

```diff
-# zoxide
-RUN curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
+# zoxide：已装在 volume 里（~/.local/bin/zoxide 0.9.4）。这层在运行时会被
+# rocm-home volume 完全遮蔽，装了也用不上；而且每次 build 都要访问 github
+# releases，没开代理必失败。需要时取消注释。
```

---

## B. VS Code 侧（两处，都在本仓库之外）

### 5. 宿主用户设置 `~/.config/Code/User/settings.json` —— **主因修复**

```diff
     "remote.autoForwardPortsSource": "hybrid",
+    "remote.autoForwardPorts": false,
+    "remote.restoreForwardedPorts": false,
```

关掉 Dev Containers 的自动端口转发，切断"转发容器内 33173 → 被自己连回"的自激环。
需要转发端口时在 PORTS 面板手动 Forward。

### 6. 容器内 `~/.vscode-server/data/Machine/settings.json` —— 收窄扫描面

新增（对**所有**工作区生效）：

```jsonc
"files.watcherExclude": { "**/.venv/**": true, "**/.cache/**": true, "**/node_modules/**": true, … }  // 19 条
"search.exclude":       { … }                                                                        // 19 条
"python.analysis.exclude": [ "**/.venv/**", "**/site-packages/**", … ]                               // 13 条
"search.followSymlinks": false
```

背景：`~/ros2` 有 57G、`~/.cache/uv` 有 20G，没有排除规则时 watcher/搜索/Pylance 会全量扫。

### 7. 工作区文件 `/home/fiz/Documents/project/ros2/workspace.code-workspace` —— 修非法 JSON

原文件结尾是 `…\t},\n  }`（多了一个 `},`），**非法 JSON，里面的 settings 从未生效**（包括 `http.proxy`）。
已重写为合法 JSONC，并同步加上第 6 条的排除规则。

---

## C. 新增：运维工具与文档（本目录）

### 8. 新增文件

```
AGENTS.md                       ← 给其他 agent 的入口说明（先读什么、按什么顺序、能不能改）
CHANGELOG-2026-11.md            ← 本文件
docs/01-症状与排查记录.md        ← 症状 + 7 条证据原文 + 5 个被推翻的假设
docs/02-三层根因与修复.md        ← 三层根因、修法、验证命令、实测对比
docs/03-排查手册.md              ← 复发时的 0→1→2→3 步操作手册
tools/memwatch.py               ← 核心探针（/proc：内存/线程/重复命令/父-祖父进程）
tools/rocm_hog_watch.sh         ← 只记录，每 N 秒采样
tools/rocm_guard.sh             ← 保险丝：超阈值先取证再 docker kill
tools/install-units.sh          ← 安装 systemd --user 服务
tools/README.md
```

systemd 用户服务（由 `tools/install-units.sh` 生成）：

```
~/.config/systemd/user/rocm-guard.service   阈值 16G，2 秒采样
~/.config/systemd/user/rocm-watch.service   20 秒采样，只记录
```

日志落在共享目录：`~/Documents/project/ros2/memwatch/{rocm_hog,rocm_guard}.log`
（容器内 `/home/rocmUser/ros2/memwatch/` 可读）。
`ros2/memwatch/` 现在**只放日志和一份说明**，代码以本目录 `tools/` 为准。

---

## 修复前后对比（同一台机器，两个 VS Code 窗口）

| 指标 | 修复前 | 修复后 |
|---|---|---|
| 内存峰值 | 16.98G（被保险丝掐断） / 更早 30G+（撑爆整机） | **5.27G** |
| `tasks` | 8417 且仍在涨 | **451，恒定** |
| `node -e` 隧道进程 | 1196 个 | **4 个** |
| 宿主 `Port forwarding` 日志 | 每秒 135 条 | 个位数 |
| 系统状态 | 卡死，需硬重启 | 正常 |
