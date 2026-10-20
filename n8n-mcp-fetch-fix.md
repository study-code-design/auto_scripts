# n8n-nodes-mcp 连接 mcp-server-fetch 失败的解决方法

## 问题现象

在 n8n 中使用社区节点 **n8n-nodes-mcp** 的 MCP Client (STDIO) 连接 `mcp-server-fetch` 时报错：

```
usage: mcp-server-fetch [-h] [--user-agent USER_AGENT] [--ignore-robots-txt]
                        [--proxy-url PROXY_URL]
mcp-server-fetch: error: unrecognized arguments:
MCP client connection error: MCP error -32000: Connection closed
Error executing tool: Failed to execute operation: Failed to connect to MCP server: MCP error -32000: Connection closed
```

即使 Arguments 字段留空、Environment 字段留空、Transport 选的是 stdio，仍然报这个错。

## 根本原因

这是 **n8n-nodes-mcp** 社区节点的一个 bug。

在文件 `dist/nodes/McpClient/McpClient.node.js` 第 361 行，参数解析逻辑是：

```js
args: cmdCredentials.args?.split(' ') || [],
```

当 Arguments 字段留空（空字符串 `""`）时：

- `""`.split(' ') 返回 `[""]`（一个包含空字符串的数组），而不是 `[]`
- 然后 `[""]` 被当作命令行参数传给了 MCP server
- `mcp-server-fetch` 收到一个空字符串作为位置参数，无法识别，启动失败
- 进程退出，连接关闭，报 `-32000`

本质：**空字符串 split 之后不是空数组，而是含空串的单元素数组**。

## 修复方法

找到 n8n 加载该社区节点的目录，修改编译后的 JS 文件。

节点通常安装在：

```
~/.n8n/nodes/node_modules/n8n-nodes-mcp/dist/nodes/McpClient/McpClient.node.js
```

找到第 361 行附近的代码：

```js
transport = new stdio_js_1.StdioClientTransport({
    command: cmdCredentials.command,
    args: ((_a = cmdCredentials.args) === null || _a === void 0 ? void 0 : _a.split(' ')) || [],
    env: env,
});
```

在 `.split(' ')` 后面加上 `.filter(Boolean)`，过滤掉空字符串：

```js
args: ((_a = cmdCredentials.args) === null || _a === void 0 ? void 0 : _a.split(' ').filter(Boolean)) || [],
```

完整修改后：

```js
transport = new stdio_js_1.StdioClientTransport({
    command: cmdCredentials.command,
    args: ((_a = cmdCredentials.args) === null || _a === void 0 ? void 0 : _a.split(' ').filter(Boolean)) || [],
    env: env,
});
```

修改完成后**重启 n8n**，节点即可正常连接。

## 快速验证修复

```bash
# 直接验证 server 本身能工作（没问题）
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | mcp-server-fetch

# 验证空参数确实会报错（复现 bug）
mcp-server-fetch ""
# 输出：mcp-server-fetch: error: unrecognized arguments:
```

## 受影响的 MCP servers

不仅是 `mcp-server-fetch`，任何**对未识别位置参数敏感**的 stdio 型 MCP server 都会被这个 bug 影响。只要 Arguments 留空就会触发。

## 注意事项

- 这是社区节点的 bug，**更新 `n8n-nodes-mcp` 包后修改会被覆盖**，需要重新打补丁
- 建议给该项目提 issue 或 PR，从源码层面修复
- 本修复只影响 stdio 模式的参数解析，不影响 SSE/HTTP 模式
