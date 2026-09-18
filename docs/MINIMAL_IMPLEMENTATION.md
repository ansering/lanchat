# 最小系统实现方案（Walking Skeleton）

> 目标：用最小代价打通“客户端 → 服务端 → 广播 → 客户端”的端到端链路，
> 验证架构与 stdx API，再在此基础上增量构建完整系统。

## 1. 目的

- 在最短时间内得到**可运行、可演示**的系统骨架。
- 尽早暴露 stdx（网络 / JSON）与 Windows 工具链的实际问题。
- 为完整系统（见 `IMPLEMENTATION_PLAN.md`）提供稳固基线。

## 2. 最小范围

**包含**

- 服务端监听、接受连接、每连接一个读线程
- 客户端连接与逐行收发
- 注册、登录（内存态、加盐 SHA-256）
- 固定房间 `general` 的群聊广播
- 一个可执行文件 `server` / `client` 两种模式

**不包含（后续迭代）**

- 私聊、多房间、创建/离开房间
- 在线列表 `/who`、房间列表 `/rooms`
- 心跳与超时清理、限流
- 错误码的完整覆盖（仅保留必要项）

## 3. 最小协议子集

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

## 4. 最小模块与函数

| 文件 | 必要内容 |
|---|---|
| `protocol.cj` | `encode`、`decode`、`readLine`、`writeLine`、消息/错误码常量、`validUsername/Password/Text` |
| `server.cj` | `Server.run`、`handleClient`、`handleRegister`、`handleLogin`、`handleSendRoom`、`send`、`broadcast` |
| `client.cj` | `Client.run`、`authPhase`、`waitAuth`、`readerLoop`、`inputLoop` |
| `main.cj` | 参数解析与服务端/客户端分派 |

## 5. 实施步骤

| 步骤 | 动作 | 产出 | 验证 |
|---|---|---|---|
| S1 | 安装工具链，跑官方 TCP + JSON 示例 | 环境可用 | 示例编译运行 |
| S2 | 固化 `protocol.cj` 的 net/JSON API | 编解码 + 分帧 | 单元测试 UT-01~04 |
| S3 | 服务端 accept + 逐行读取 + 回显 | 连接可用 | `nc`/客户端观察 |
| S4 | 注册 / 登录 | 认证闭环 | 客户端登录成功 |
| S5 | `join` 固定 `general` + 群聊广播 | 端到端聊天 | 两客户端互聊 |
| S6 | 客户端命令与显示格式 | 可用界面 | 双终端演示 |

> S2 是风险最高的一步，必须先于其余步骤完成。

## 6. 最小系统验收（DoD）

- [ ] `cjpm build` 通过，`cjpm test` 通过（最小单测）
- [ ] 主机启动 `lanchat server`，日志打印监听端口
- [ ] 两个终端 `lanchat client <host>` 可注册、登录
- [ ] 两终端加入 `general` 后互发消息可见
- [ ] 关闭一端，服务端日志显示断线
- [ ] 畸形 JSON 不影响服务端存活（对应单测或手工验证）

## 7. 演示脚本

```powershell
# 主机
cjpm run -- server

# 终端 A
cjpm run -- client 192.168.1.10
# 注册 alice / 登录 alice

# 终端 B
cjpm run -- client 192.168.1.10
# 注册 bob / 登录 bob

# 双方发送普通文本，观察广播
```

## 8. 与完整系统的关系

最小系统保留了三层结构（协议 / 服务端 / 客户端）与并发模型（`gLock` + 每会话 `writeLock`）。
完整系统仅在此基础上**做加法**，不改变骨架：

| 能力 | 增量位置 |
|---|---|
| 私聊 | `server.handleSendPrivate` + `client` 命令 |
| 多房间 | `server` 房间管理与 `client /join /rooms` |
| 心跳清理 | `server.startSweeper` |
| 校验与错误 | `protocol` 校验 + 错误码 |
| 测试 | `tests/` 单元与集成 |
