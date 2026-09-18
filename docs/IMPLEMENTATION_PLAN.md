# 完整系统实现方案

> 在最小系统（`MINIMAL_IMPLEMENTATION.md`）基础上，按迭代增量实现完整 v1.0。
> 本文档给出迭代划分、模块实现要点、构建顺序与需求追踪矩阵。

## 1. 实现策略

- **增量迭代**：每个迭代都保持可编译、可运行、可演示。
- **协议先行**：新增消息类型先更新 `DEVELOPMENT.md` §5，再改 `protocol.cj`。
- **纵向切片**：每个功能尽量贯穿“协议 → 服务端 → 客户端 → 测试”。
- **不破坏骨架**：始终为 1 工程、1 可执行文件、4 源文件（测试另置于 `tests/`）。

## 2. 迭代划分

| 迭代 | 名称 | 范围 | 依赖 |
|---|---|---|---|
| I0 | 最小系统 | 连接、注册/登录、单房间群聊 | — |
| I1 | 多房间 | 创建/加入/离开、房间列表、加入/离开通知 | I0 |
| I2 | 私聊与在线 | 私聊、`/who` 在线列表 | I1 |
| I3 | 健壮性 | 心跳清理、字段校验、错误码完善、限长 | I2 |
| I4 | 测试与交付 | 单元/集成测试、README、三机联调 | I3 |

### I1 多房间

| 项 | 内容 |
|---|---|
| 协议 | `list_rooms`、`create_room`、`join_room`、`leave_room`、`room_list`、`system` |
| 服务端 | `rooms` 容器、`handleListRooms/handleCreateRoom/handleJoinRoom/handleLeaveRoom`、`leaveCurrentRoom` |
| 客户端 | 命令 `/join`、`/rooms`；维护当前房间 |
| 不变量 | INV-2、INV-3（见 `DEVELOPMENT.md` §6.5） |
| 验收 | IT-03；两客户端切换到同一房间后消息隔离正确 |

### I2 私聊与在线

| 项 | 内容 |
|---|---|
| 协议 | `send_private`、`who`、`user_list`、`message(scope=private)` |
| 服务端 | `handleSendPrivate`（按用户名查 `sessions`，离线返回 1005）、`handleWho` |
| 客户端 | 命令 `/msg <user> <text>`、`/who`；私聊消息 `[私聊]` 前缀 |
| 验收 | IT-05、IT-06 |

### I3 健壮性

| 项 | 内容 |
|---|---|
| 心跳 | 客户端周期 `ping`（建议 30s）；服务端 `lastSeen` + 巡检线程（90s 超时清理） |
| 校验 | 用户名/密码/房间/文本按 §5.9 校验，返回 1006 |
| 限长 | 单行 > 64 KiB 关闭连接 |
| 失败隔离 | 单连接解析/处理异常不影响进程 |
| 并发 | 统一锁顺序 `gLock → writeLock`；广播先在锁内收集目标再释放锁发送 |
| 验收 | IT-08、IT-09、NFR-1、NFR-4 |

### I4 测试与交付

| 项 | 内容 |
|---|---|
| 单元测试 | 编解码、校验、哈希、房间逻辑（`tests/`） |
| 集成测试 | 以脚本客户端跑通 IT-01~09 |
| 文档 | README、部署说明、协议与实现一致性核对 |
| 联调 | 三台电脑同一 WiFi 实测 |

## 3. 模块实现要点

### 3.1 protocol.cj

- 常量集中：`MSG_*`、`ERR_*`、限制值。
- 编解码：`encode`/`decode`，全部 JSON 访问封装为 `putStr/putInt/putStrArray/getStr/getOptStr/getInt/getStrArray`。
- 分帧：`readLine`/`writeLine`；`readLine` 处理 `\r\n`、空行、超长。
- 校验：`validUsername/validPassword/validRoom/validText`。
- 构造：`okMsg/errMsg/systemMsg/chatMsg`。

### 3.2 server.cj

- 数据模型：`User`、`Room`、`Session`、`Server`。
- 接入：`run` → `accept` → `spawn handleClient`。
- 分发：`dispatch` 先做认证态检查，再 `match(type)`。
- 认证：`handleRegister`/`handleLogin`；同名重复登录踢旧会话。
- 房间：默认 `general`；加入即离开旧房间；广播加入/离开。
- 消息：`handleSendRoom`/`handleSendPrivate`。
- 发送：`send` 持 `writeLock`；`broadcast` 先收集后发送。
- 清理：`cleanup` 移出房间、移除会话、关 socket、广播离开。
- 心跳：`startSweeper` 周期清理超时会话。

### 3.3 client.cj

- 认证阶段：菜单式注册/登录，`waitAuth` 等待结果。
- 读线程：`readerLoop` 收消息并格式化打印。
- 输入线程：`inputLoop` 解析命令或文本。
- 同步：`writeLock` 保护发送，`outLock` 保护打印。
- 显示：房间 / 私聊 / 系统 / 错误四类格式（见 §8.2）。

### 3.4 main.cj

- `server [port]`、`client <host> [port]` 分派与用法提示。

## 4. 关键设计决策

| 决策 | 理由 |
|---|---|
| 按行 JSON 分帧 | 免去长度前缀与粘包处理，初学者友好 |
| 单一全局锁 | 概念少、易推断；规模小性能足够 |
| 每会话写锁 | 允许广播并发而不用全局串行写 |
| 广播先收集后发送 | 避免持 `gLock` 时做阻塞 I/O |
| 内存态存储 | 降低复杂度；重启即清空可接受 |
| 无 reqId | 简化协议；同步式交互足够 |

## 5. 构建顺序

```
protocol.cj ──► server.cj（注册/登录）──► client.cj（认证）
      │                                          │
      └──► 单测（编解码/校验）                    ▼
                                    server 房间/消息 ──► client 命令
                                                 │
                                                 ▼
                                          心跳/健壮性 ──► 测试与联调
```

## 6. 需求追踪矩阵

| 需求 | 迭代 | 模块 | 测试 |
|---|---|---|---|
| FR-1 注册 | I0 | server.auth / protocol | UT-07, IT-01 |
| FR-2 登录 | I0 | server.auth | IT-02 |
| FR-3 房间 | I1 | server.room | IT-03 |
| FR-4 群聊 | I0/I1 | server.broadcast | IT-04 |
| FR-5 私聊 | I2 | server.private | IT-05, IT-06 |
| FR-6 系统通知 | I1 | server.broadcast | IT-03, IT-07 |
| FR-7 心跳清理 | I3 | server.sweeper | IT-08 |
| FR-8 终端显示 | I0 | client | 手工 |
| FR-9 列表/在线 | I1/I2 | server / client | IT-03, IT-05 |
| FR-10 参数配置 | I0 | main | 手工 |
| NFR-1 限长 | I3 | protocol.readLine | UT-04 |
| NFR-2 密码哈希 | I0 | server.auth | UT-05, UT-06 |
| NFR-3 写互斥 | I0 | Session.writeLock | 评审 |
| NFR-4 失败隔离 | I3 | server.handleClient | IT-09 |
| NFR-6 WiFi 部署 | I4 | 部署 | 三机联调 |

## 7. 交付物清单

| 交付物 | 位置 |
|---|---|
| 工程配置 | `cjpm.toml` |
| 源代码 | `src/main.cj`、`protocol.cj`、`server.cj`、`client.cj` |
| 单元/集成测试 | `tests/` |
| 开发文档 | `docs/DEVELOPMENT.md` |
| 实施文档 | `docs/MINIMAL_IMPLEMENTATION.md`、`IMPLEMENTATION_PLAN.md`、`IMPLEMENTATION_PROCESS.md`、`DEVELOPMENT_TESTING.md` |
| 运行说明 | `docs/README.md` |

## 8. 风险与缓解（实现视角）

| 风险 | 缓解 |
|---|---|
| stdx API 不确定 | 全部集中在 `protocol.cj` 与少量辅助函数；I0 先校准 |
| 锁使用不当 | 统一锁顺序；评审清单强制检查 |
| 持锁 I/O 导致卡顿 | `broadcast` 先收集后发送 |
| 功能蔓延 | 严格按迭代范围，超范围记入 v2 |
| 初学者上手慢 | 每迭代保持可运行；提供伪代码与指引 |
