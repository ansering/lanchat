# 最小系统实现方案（代码框架）

> 目标：只搭建**可扩展的代码框架**——类型、常量、函数签名与模块边界，
> 不编写具体业务实现。具体逻辑留待 M2（见 `IMPLEMENTATION_PLAN.md`）。
>
> 一句话：最小实现 = 骨架，不是能跑通的系统。

## 1. 目的

- 固定工程结构与模块边界，让后续开发“往空函数里填逻辑”。
- 固化协议契约（消息类型、错误码、字段）与并发约定。
- 尽早暴露 stdx 与 Windows 工具链问题（但不阻塞框架搭建）。

## 2. 框架范围

**包含（本阶段交付）**

- `cjpm.toml` 工程配置（含 stdx 依赖说明）
- 四个源文件：`main.cj`、`protocol.cj`、`server.cj`、`client.cj`
- 消息类型 / 错误码 / 限制值等**常量**
- 数据模型（`User` / `Room` / `Session` / `Server` / `Client`）的**字段**
- 全部关键函数的**签名**，函数体为 `TODO` 占位（返回 `todo(...)`）
- 入口 `main` 的参数解析与模式分派（结构，非业务）

**不包含（M2 及以后）**

- 任何具体算法：编解码、校验、哈希、房间管理、消息路由、心跳
- 任何 stdx API 的实际调用实现
- 可运行、可演示的聊天功能
- 单元测试与集成测试

## 3. 协议契约（框架已定义常量的部分）

| 方向 | type | 字段 | 响应 |
|---|---|---|---|
| C→S | `register` | `username, password` | `ok` / `error` |
| C→S | `login` | `username, password` | `login_ok` / `error` |
| C→S | `send_room` | `room, text` | 广播 `message` |
| C→S | `ping` | — | `pong` |
| S→C | `ok` / `error` | `action` / `code,message` | — |
| S→C | `login_ok` | `username, rooms` | — |
| S→C | `message` | `scope,room,from,text,ts` | — |
| S→C | `system` | `text,ts` | — |

分帧：一行一条 JSON，`\n` 结尾，单行 ≤ 64 KiB。

## 4. 模块与签名清单

| 文件 | 框架内容（签名） |
|---|---|
| `protocol.cj` | `todo`、`encode`、`decode`、`newMsg`、`putStr/putInt/putStrArray`、`getStr/getOptStr/getInt/getStrArray`、`readLine`、`writeLine`、`validUsername/Password/Room/Text`、`nowSeconds`、`okMsg/errMsg/systemMsg/chatMsg` |
| `server.cj` | `User`、`Room`、`Session`、`Server`；`run`、`handleClient`、`dispatch`、各 `handle*`、`send`、`broadcast`、`cleanup`、`startSweeper` |
| `client.cj` | `Client`；`run`、`connect`、`authPhase`、`readerLoop`、`handle`、`inputLoop`、`send`、`printLine` |
| `main.cj` | `main(args)`、`parsePort`、`printUsage` |

> 所有未实现函数体为：非 `Unit` 返回 `todo("名称")`，`Unit` 函数体为空并附 `TODO(M2)` 注释。

## 5. 实施步骤

| 步骤 | 动作 | 产出 | 验证 |
|---|---|---|---|
| S1 | 安装工具链，跑官方 TCP + JSON 示例 | 环境可用 | 示例编译运行 |
| S2 | 建立四文件框架与 `cjpm.toml` | 骨架代码 | 结构完整、签名齐全 |
| S3 | 定义协议常量与数据模型字段 | 契约固化 | 与 `DEVELOPMENT.md` §5 一致 |
| S4 | 填充 TODO 占位，保持可编译 | 可编译骨架 | `cjpm build`（M0 校准后） |

> 本阶段**不做**编解码/服务端/客户端的业务实现。

## 6. 框架验收（DoD）

- [ ] 工程为单模块、单可执行文件、四个源文件
- [ ] 协议常量、错误码、限制值与 `DEVELOPMENT.md` 一致
- [ ] 所有关键函数**签名齐全**，函数体为占位并标注 `TODO(M2)`
- [ ] 数据模型字段与 `DEVELOPMENT.md` §6.2 一致
- [ ] `cjpm.toml` 含 stdx 依赖说明（见 `DEPENDENCIES.md`）
- [ ] 不包含任何具体业务实现

## 7. 边界说明

框架阶段**不要求**程序能实际运行聊天；`todo(...)` 会在调用时抛出异常，
这是刻意为之，用于标记尚未实现的功能点。M0 校准 stdx 后按 M2 逐项填充。

## 8. 与完整系统的关系

框架固定了三层结构（协议 / 服务端 / 客户端）与并发模型（`gLock` + 每会话 `writeLock`）。
完整系统仅在空函数中**填充实现**，不改变骨架：

| 能力 | 填充位置 |
|---|---|
| 编解码 / 校验 / 分帧 | `protocol.cj` |
| 注册、登录 | `server.handleRegister/handleLogin` |
| 群聊、私聊 | `server.handleSendRoom/handleSendPrivate` |
| 多房间 | `server.handleJoinRoom/handleLeaveRoom` |
| 心跳清理 | `server.startSweeper` |
| 客户端界面与命令 | `client.readerLoop/inputLoop` |
| 测试 | `tests/` |
