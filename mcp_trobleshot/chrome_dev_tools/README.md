# 配置一个持久化的、由 AI 操纵的 Chrome

> 环境：CachyOS / KDE Plasma (Wayland) · Chrome 156 · chrome-devtools-mcp 1.12 · pi coding agent
> 目标：让 `chrome-devtools-mcp` 操纵**常驻**的 Chrome —— 换会话、重启 pi、MCP 进程被 SIGKILL，浏览器都不关。

---

## 1. 问题现象

每次在 pi 里开新对话，浏览器就自动关闭；旧会话留下的 `chrome-devtools-mcp` 进程还赖着不走。

## 2. 根因

`chrome-devtools-mcp` 是 **stdio MCP server**，而 Chrome 是它 `puppeteer.launch()` 出来的**子进程**：

```
pi ──spawn──> npm exec ──> chrome-devtools-mcp ──launch──> chrome  ← 会话结束一起死
```

pi 关闭 stdio server 的逻辑（`docs/mcp.md`）：

> Stopping a stdio server closes its stdin, sends SIGTERM, then sends SIGKILL to its **process group**.

进程组一起杀 ⇒ MCP 死、Chrome 跟着死。另外它默认每次都用 `~/.cache/chrome-devtools-mcp/chrome-profile` 起一个「干净」实例，登录态也不保留。

**结论：只要 Chrome 是 MCP 的子进程，就一定会被带走。必须把 Chrome 的所有权从「MCP」转移给「systemd」。**

## 3. 总体方案

```
systemd --user ──> Chrome_by_Agent (chrome --remote-debugging-port=9222, 独立 profile)
                          ▲
                          │  CDP over http://127.0.0.1:9222
pi ──> chrome-devtools-mcp --browserUrl  (只连接，不启动)
```

`chrome-devtools-mcp` 有两种模式（`--help`）：

| 模式 | 行为 | 适用 |
|---|---|---|
| 默认（`--headless` / `--isolated` / `--userDataDir` …） | 自己 launch 一个 Chrome，绑定生命周期 | 一次性任务 |
| `-u, --browserUrl` / `-w, --wsEndpoint` / `--autoConnect` | 连接到**已经存在**的可调试 Chrome | 常驻、多会话复用 ✅ |

用 `--browserUrl` 之后，MCP 死多少次都和浏览器无关。

## 4. 落地文件（本机实际部署）

| 路径 | 作用 |
|---|---|
| `~/bin/Chrome_by_Agent` | 启动脚本（幂等，可手动也可被 systemd 调） |
| `~/.config/systemd/user/Chrome_by_Agent.service` | 用户级 unit，登录后自启、挂了自动拉回 |
| `~/.pi/agent/mcp.json` | MCP 端改成 `--browserUrl` |
| `~/.local/share/chrome-by-agent-profile` | 独立 profile（登录态、书签长期保留），日志在同目录 `chrome.log` |

### 4.1 启动脚本 `~/bin/Chrome_by_Agent`

```bash
#!/usr/bin/env bash
# Chrome_by_Agent —— 常驻「调试用 Chrome」，给 chrome-devtools-mcp 用 --browserUrl 连接。
# 独立进程运行：pi 会话结束 / MCP 被 SIGTERM 都不会把它带走。
set -uo pipefail

export HOME="${HOME:-/home/fiz}"
PORT="${CHROME_DEBUG_PORT:-9222}"
PROFILE="${CHROME_DEBUG_PROFILE:-$HOME/.local/share/chrome-by-agent-profile}"
URL="http://127.0.0.1:${PORT}"

# 已经在跑就直接退出（幂等）；unit 随之变 inactive，且不会自动重启
if curl -fsS --max-time 2 "$URL/json/version" >/dev/null 2>&1; then
    exit 0
fi

CHROME="${CHROME_BIN:-}"
if [[ -z "$CHROME" ]]; then
    for c in google-chrome-stable google-chrome chromium chromium-browser; do
        if command -v "$c" >/dev/null 2>&1; then CHROME="$(command -v "$c")"; break; fi
    done
fi
[[ -n "$CHROME" && -x "$CHROME" ]] || { echo "Chrome_by_Agent: 找不到 Chrome" >&2; exit 1; }

# 作为服务运行时没有图形会话环境，自己补齐
RUN_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export XDG_RUNTIME_DIR="$RUN_DIR"
[[ -z "${DISPLAY:-}" ]] && export DISPLAY=:0
if [[ -z "${XAUTHORITY:-}" ]]; then
    for f in "$RUN_DIR"/xauth_* "$HOME/.Xauthority"; do
        [[ -f "$f" ]] && { export XAUTHORITY="$f"; break; }
    done
fi

mkdir -p "$PROFILE"

exec "$CHROME" \
    --remote-debugging-port="$PORT" \
    --user-data-dir="$PROFILE" \
    --no-first-run \
    --no-default-browser-check \
    --disable-features=ChromeWhatsNewUI \
    --class=Chrome_by_Agent \
    "$@" >>"$PROFILE/chrome.log" 2>&1
```

要点：

- **`--user-data-dir` 必须不是默认目录**：Chrome 136+ 出于安全默认拒绝在默认 profile 上开 `--remote-debugging-port`。用独立 profile 同时也顺便解决了「日常 Chrome 开着就不能再开调试端口」的冲突。
- **日志重定向到文件**：`chrome` 往 stdout 里吐的东西绝不能进 MCP 的 stdout（那是在传 JSON-RPC）。
- **幂等**：先用 `curl /json/version` 探活，避免 systemd 重启时起出两个 Chrome 抢同一个 profile。
- **`XAUTHORITY` 兜底**：KDE Wayland 下 XWayland 的 auth 文件是 `/run/user/1000/xauth_XXXXXX`，每会话变名，所以要 glob。

### 4.2 用户级 unit `~/.config/systemd/user/Chrome_by_Agent.service`

手动管理生命周期的版本（**不**开机自启、**不**自动拉起）：

```ini
[Unit]
Description=Chrome_by_Agent - persistent Chrome with remote debugging for chrome-devtools-mcp
Documentation=https://github.com/ChromeDevTools/chrome-devtools-mcp

[Service]
Type=simple
Environment=CHROME_DEBUG_PORT=9222
ExecStart=%h/bin/Chrome_by_Agent
# 手动管理生命周期：不要开机自启，也不要在关掉窗口/进程退出后自动拉起
Restart=no
TimeoutStopSec=10
```

```bash
chmod +x ~/bin/Chrome_by_Agent
systemctl --user daemon-reload
# 注意是 start，不是 enable --now
systemctl --user start Chrome_by_Agent.service
```

关键选择（这两条决定了它到底是「常驻服务」还是「按需工具」）：

| 想要的行为 | 配置 |
|---|---|
| 登录就自动开（常驻） | `Restart=always` + `[Install] WantedBy=graphical-session.target` + `systemctl --user enable` |
| **按需：需要时 start，关窗口就没了**（本文默认） | `Restart=no` + **不写 `[Install]`** + 只 `start` |

不写 `[Install]` 的 unit 是 `static` 状态：`systemctl --user enable` 直接无效，从机制上就不可能被开机自启。也**不要**把它软链到 `graphical-session.target.wants/` 里。

用户级（`systemctl --user`）优于系统级（`/etc/systemd/system`）：不需要 root、天然继承你的图形会话环境，代价只是「登录后才存在」。

### 4.3 MCP 端 `~/.pi/agent/mcp.json`

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": [
        "-y",
        "chrome-devtools-mcp@latest",
        "--browserUrl=http://127.0.0.1:9222",
        "--screenshotFormat=webp"
      ],
      "description": "Drive and debug Chrome over the DevTools Protocol: navigate, click, type, read DOM/console/network, screenshot, CPU and memory profiling, performance traces."
    }
  }
}
```

改完在 pi 里 `/reload` 或重开对话。其他客户端（Claude Code / Cursor / Codex）同理，加 `--browserUrl` 即可。

## 5. 验证清单

```bash
# 1) 端口和浏览器信息
curl -s http://127.0.0.1:9222/json/version

# 2) Chrome 的爸爸是谁 —— 关键！必须是 systemd --user，不能是 node/npm
ps -o pid,ppid,args -p $(pgrep -f 'remote-debugging-port=9222' | head -1) | cut -c1-120
ps -o pid,args -p $(ps -o ppid= -p <chrome_pid> | tr -d ' ')

# 3) 服务状态
systemctl --user status Chrome_by_Agent
```

MCP 侧冒烟测试（不依赖 pi，直接走 stdio 握手 + `list_pages`）：

```bash
cat > /tmp/mcp-smoke.mjs <<'EOF'
import { spawn } from 'node:child_process';
const p = spawn('npx', ['-y','chrome-devtools-mcp@latest','--browserUrl=http://127.0.0.1:9222'],
                { stdio: ['pipe','pipe','inherit'] });
let buf = '';
const send = (o) => p.stdin.write(JSON.stringify(o) + '\n');
p.stdout.on('data', (d) => {
  buf += d;
  let i;
  while ((i = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, i); buf = buf.slice(i + 1);
    let m; try { m = JSON.parse(line); } catch { continue; }
    if (m.id === 1) {
      console.log('init ok:', JSON.stringify(m.result?.serverInfo));
      send({ jsonrpc: '2.0', method: 'notifications/initialized' });
      send({ jsonrpc: '2.0', id: 2, method: 'tools/call',
             params: { name: 'list_pages', arguments: {} } });
    }
    if (m.id === 2) { console.log('pages:', JSON.stringify(m.result).slice(0, 300)); p.kill(); process.exit(0); }
  }
});
send({ jsonrpc: '2.0', id: 1, method: 'initialize',
       params: { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'smoke', version: '1' } } });
setTimeout(() => { console.log('TIMEOUT'); p.kill(); process.exit(1); }, 60000);
EOF
node /tmp/mcp-smoke.mjs
```

预期：`init ok: {"name":"chrome_devtools",...}` + 一串页面列表。

## 6. 日常操作

```bash
systemctl --user start  Chrome_by_Agent     # 需要时启动
systemctl --user stop   Chrome_by_Agent     # 手动停（Chrome 一起关）
systemctl --user status Chrome_by_Agent     # 看状态
journalctl --user -u Chrome_by_Agent -f     # unit 日志
tail -f ~/.local/share/chrome-by-agent-profile/chrome.log   # Chrome 自身日志
```

- **直接点窗口的 ×** 也行：Chrome 退出码 0 → unit 变 `inactive (dead)`，`Restart=no` 不会把它拉回来。
- 手动 `stop` 之后，pi 里的 chrome-devtools 工具会连不上（`--browserUrl` 要求浏览器已在跑）；用之前 `start` 一下。
- 想「用到时自动起、不用时也自己关」见 §8.3 的包装脚本。

## 7. 踩过的坑

1. **Chrome 拒绝在默认 user-data-dir 上开调试端口**（136+）→ 必须 `--user-data-dir` 指向别处（官方说明：<https://developer.chrome.com/blog/remote-debugging-port>）；也意味着「复用你日常 Chrome 的登录态」这条路走不通，得在新 profile 里重新登录一次。
2. **`--viewport` 对连接的实例无效** —— 它只作用于「server 自己 launch 的浏览器」。连通后可用 `resize_page` 改视口。
3. **`pkill -f 'user-data-dir=/path/x'` 会把自己也杀了**：`bash -c` 的命令行本身含有这个字符串，pattern 命中了自己 → `exit 143`。用 `pgrep -f 'remote-debugging-port=9222'` 或者按 pid 杀。
4. **`Restart=always` 会让「关窗口」变成「关不掉」**：Chrome 正常退出码 0，`Restart=always` 照样立刻重启；再叠加 `enable` 挂到 `graphical-session.target`，就是「登录自己冒出来 + 永远关不掉」。要按需用手动管理，就 `Restart=no` + 不写 `[Install]`。
5. **Type=simple + 幂等脚本要小心**：脚本发现端口已被占用就 `exit 0`，unit 立刻变 `inactive`。若同时配了 `Restart=always` 就会 5 秒一次地无限重启刷日志；想让 unit 保持 active 得让脚本挂住（`exec sleep infinity`）。本文选了 `Restart=no`，所以脚本直接 `exit 0` 即可。
6. **系统级服务起 GUI 程序很脆**：没有 `DISPLAY`/`WAYLAND_DISPLAY`/`XAUTHORITY`，`/run/user/1000` 也可能还没建好。能用户级就别系统级。
7. **旧的 MCP 孤儿进程会残留**（`npm exec → chrome-devtools-mcp → telemetry watchdog`）。换配置前 `ps -eo pid,ppid,args | grep chrome-devtools-mcp` 看一眼，父进程不是活的 pi 就可以清掉。
8. **MCP roots 警告**：`The connecting client did not negotiate the MCP roots capability. Tools that read or write local files will be restricted to the OS temp directory.` 即 pi 没实现 roots，文件类工具只能写 `/tmp`。需要放开就把 `--allow-unrestricted-paths`（已弃用，等价 `--workspace=/`）或 `--workspace=/某个目录` 加到 args 里。
9. **`--screenshotFormat=webp` 是为了省 context**：截图 token 随尺寸走，配合 `--screenshotMaxWidth=1280` 更省。

## 8. 进阶选项

### 8.1 多会话共用一个 Chrome

`--page-id-routing`（默认 `true`）让每个 page 级工具带 `pageId`，多个 pi 会话同时开着也不会互相抢「当前页面」。若你的客户端很老、不认识 pageId，用 `--no-page-id-routing` 退回单页面语义。

需要完全隔离（比如并行跑两个不同任务的自动化）时，就别共享了：再起一个实例，换端口 + 换 profile。

```bash
CHROME_DEBUG_PORT=9333 CHROME_DEBUG_PROFILE=~/.local/share/chrome-by-agent-2 \
  ~/bin/Chrome_by_Agent &
# 另一个 MCP 客户端用 --browserUrl=http://127.0.0.1:9333
```

### 8.2 复用日常 Chrome（`--autoConnect`）

Chrome 144+ 支持：在**你日常的** Chrome 里打开 `chrome://inspect/#remote-debugging` 启用远程调试，然后 MCP 用 `--autoConnect`（默认 channel=stable）连上去。好处是全套书签/登录态；坏处是每次都要在 UI 里点开关，且 Chrome 会弹授权确认。

### 8.3 不用时自动关、要用时自动起

```bash
# systemd socket 激活思路：监听 9222，有连接时再起 Chrome。
# 更简单的做法是给 MCP 加一层包装脚本：连不上就先 systemctl --user start。
```

包装脚本示例（`~/.pi/agent/bin/cdmcp.sh`），MCP 配置里把它当 `command`：

```bash
#!/usr/bin/env bash
systemctl --user start Chrome_by_Agent
for _ in $(seq 1 20); do
  curl -fsS --max-time 1 http://127.0.0.1:9222/json/version >/dev/null 2>&1 && break
  sleep 0.5
done
exec npx -y chrome-devtools-mcp@latest --browserUrl=http://127.0.0.1:9222 --screenshotFormat=webp
```

## 9. 迁移到别的机器

1. 拷 `~/bin/Chrome_by_Agent` + `~/.config/systemd/user/Chrome_by_Agent.service`。
2. 改脚本里的 `HOME` 默认值、确认 Chrome 路径（`--channel beta|dev|canary|stable` 或 `--executablePath`）。
3. `chmod +x` → `systemctl --user daemon-reload`（按需启动，不要 `enable`）。
4. MCP 配置加 `--browserUrl=http://127.0.0.1:9222`。
5. 按 §5 的三步验证一遍（**最关键是第 2 步：Chrome 的父进程必须是 `systemd --user`**）。
