# LAN Chat 系统开发文档

**基于仓颉语言的 WiFi 局域网聊天系统**

| 项目 | 内容 |
|---|---|
| 文档名称 | LAN Chat 系统开发文档 |
| 文档版本 | v1.0 |
| 文档状态 | 已评审（基线） |
| 适用产品版本 | LAN Chat v1.0 |
| 目标平台 | Windows 10/11、Windows Server |
| 部署形态 | 同一 WiFi 局域网，单主机 + 多终端 |
| 作者 / 维护 | LAN Chat 项目组 |
| 最后更新 | 2026-09-18 |

## 修订记录

| 版本 | 日期 | 说明 |
|---|---|---|
| v0.1 | 2026-09-18 | 初稿，确定功能与架构方向 |
| v0.2 | 2026-09-18 | 面向初学者精简系统结构 |
| v1.0 | 2026-09-18 | 专业详细化：补齐需求规格、协议规范、详细设计、测试与部署 |

## 术语与缩写

| 术语 | 说明 |
|---|---|
| 主机（Host） | 运行服务端、作为中心节点的电脑 |
| 终端（Terminal） | 运行客户端、连接主机的电脑 |
| 帧 / 消息 | 一次完整的协议传输单元（本系统为一行 JSON） |
| 房间（Room） | 一组用户的聊天频道 |
| 会话（Session） | 服务端对一条客户端连接的运行时表示 |
| FR / NFR | 功能需求 / 非功能需求 |
| DoD | 完成定义（Definition of Done） |
| cjpm | 仓颉包管理与构建工具 |
| stdx | 仓颉扩展标准库（含网络、JSON 等） |

---

## 目录

1. [引言](#1-引言)
2. [项目概述](#2-项目概述)
3. [需求规格](#3-需求规格)
4. [系统架构](#4-系统架构)
5. [通信协议规范](#5-通信协议规范)
6. [数据设计](#6-数据设计)
7. [详细设计](#7-详细设计)
8. [客户端设计](#8-客户端设计)
9. [安全设计](#9-安全设计)
10. [开发规范](#10-开发规范)
11. [开发流程](#11-开发流程)
12. [测试方案](#12-测试方案)
13. [部署与运行](#13-部署与运行)
14. [开发计划](#14-开发计划)
15. [风险与应对](#15-风险与应对)
16. [附录](#16-附录)

---

## 1. 引言

### 1.1 目的

本文档定义 LAN Chat 系统的功能需求、系统架构、通信协议、数据模型、详细设计与工程规范，
作为项目组开发、测试、部署与验收的统一依据。

### 1.2 范围

本文档覆盖 LAN Chat v1.0 的完整生命周期内容，包括：

- 需求规格与验收标准
- 系统架构与并发模型
- 应用层通信协议规范
- 各模块详细设计
- 测试、部署与开发流程

### 1.3 读者对象

- 项目组开发人员（含初学者）：作为实现与自查依据
- 测试人员：作为用例设计依据
- 项目负责人：作为进度与验收依据

### 1.4 文档约定

- 需求编号：`FR-x`（功能）、`NFR-x`（非功能）
- 优先级：**P0**（必须）、**P1**（应当）、**P2**（可选）
- `MUST / SHOULD / MAY` 分别表示强制 / 建议 / 可选
- 协议字段以 `等宽字体` 标注，类型以 `string`、`int64` 等标注

### 1.5 参考资料

- 仓颉语言官方文档与标准库 API
- `stdx.net`（TCP）、`stdx.encoding.json`（JSON）
- `std.console`、`std.crypto.digest`、`std.sync`、`std.time`

---

## 2. 项目概述

### 2.1 背景与目标

在无互联网或不便使用公网服务的场景下，利用 WiFi 局域网搭建轻量即时聊天系统。
项目同时作为仓颉语言的教学实践，强调**结构简单、逻辑清晰、易于调试**。

### 2.2 系统定位

- 单主机、多终端的中心化架构（客户端—服务端）。
- 数据存于内存，无持久化，适合临时协作与教学演示。
- 提供群聊、私聊、多房间与账号认证四项核心能力。

### 2.3 设计原则

| 编号 | 原则 | 说明 |
|---|---|---|
| DP-1 | 简单优先 | 一个工程、一个可执行文件、四个源文件 |
| DP-2 | 显式分层 | 协议编解码与业务逻辑分离 |
| DP-3 | 单锁保护 | 共享状态用统一互斥锁，降低死锁风险 |
| DP-4 | 可读性优先 | 命名清晰、函数短小、避免过度抽象 |
| DP-5 | 失败隔离 | 单连接异常不得影响服务端整体 |
| DP-6 | 契约先行 | 协议文档与代码同步演进 |

### 2.4 约束与假设

| 类型 | 内容 |
|---|---|
| 约束 | 必须使用仓颉语言与 cjpm 构建 |
| 约束 | 目标平台为 Windows |
| 约束 | 所有节点处于同一 WiFi 子网 |
| 假设 | 网络延迟低、丢包少（局域网） |
| 假设 | 同时在线上限约数十人，规模较小 |
| 假设 | 允许服务端重启丢失全部数据 |

---

## 3. 需求规格

### 3.1 用户角色

| 角色 | 描述 |
|---|---|
| 访客 | 未登录的连接，仅可注册/登录 |
| 用户 | 已登录，可加入房间、收发消息 |
| 主机操作员 | 在主机上启动/停止服务端并配置端口 |

### 3.2 主要用例

| 用例 | 参与者 | 描述 |
|---|---|---|
| UC-1 注册 | 访客 | 创建账号 |
| UC-2 登录 | 访客 | 验证身份并建立会话 |
| UC-3 加入房间 | 用户 | 进入/切换房间 |
| UC-4 群聊 | 用户 | 向所在房间广播消息 |
| UC-5 私聊 | 用户 | 向指定在线用户发送消息 |
| UC-6 查看在线 | 用户 | 查看房间在线成员 |
| UC-7 断开 | 系统 | 检测断线并清理 |

### 3.3 功能需求

| 编号 | 优先级 | 需求 | 验收要点 |
|---|---|---|---|
| FR-1 | P0 | 用户可用唯一用户名和密码注册 | 重名注册返回 `1002` |
| FR-2 | P0 | 已注册用户可登录 | 密码错误返回 `1003` |
| FR-3 | P0 | 用户可创建、加入、离开房间 | 默认 `general`；不存在返回 `1004` |
| FR-4 | P0 | 房间消息广播给全体成员 | 发送者与其它成员均收到 |
| FR-5 | P0 | 用户可私聊在线用户 | 仅目标收到；离线返回 `1005` |
| FR-6 | P0 | 加入/离开产生系统通知 | 房间成员收到 `system` |
| FR-7 | P0 | 心跳检测与断线清理 | 超时连接被关闭并广播离开 |
| FR-8 | P0 | 客户端终端收发与显示消息 | 多终端可视化联调通过 |
| FR-9 | P1 | 查看房间列表与在线成员 | `/rooms`、`/who` 可用 |
| FR-10 | P1 | 客户端可配置主机 IP 与端口 | 命令行参数生效 |

### 3.4 非功能需求

| 编号 | 类别 | 需求 | 指标 |
|---|---|---|---|
| NFR-1 | 容量 | 单行消息上限 | 64 KiB，超限关闭连接 |
| NFR-2 | 安全 | 密码不得明文存储 | 加盐 SHA-256 |
| NFR-3 | 并发 | 同连接写操作互斥 | 每会话写锁 |
| NFR-4 | 健壮 | 畸形输入可恢复 | 仅关闭该连接，进程存活 |
| NFR-5 | 性能 | 局域网往返延迟 | < 100 ms |
| NFR-6 | 可用 | 支持 WiFi 单主机多终端 | 三机联调通过 |
| NFR-7 | 可维护 | 单文件职责单一 | 每文件 ≤ 约 400 行 |

### 3.5 范围外

消息持久化、离线消息、文件/图片传输、全屏 TUI、服务端管理后台、角色权限、
TLS 加密、NAT 穿透、跨子网、桌面 GUI。

---

## 4. 系统架构

### 4.1 拓扑

```
                  同一 WiFi 局域网（同一网段，如 192.168.1.x）
 [终端电脑 A] ─┐
 [终端电脑 B] ─┼── WiFi ──► [主机电脑：lanchat server  :9000]
 [终端电脑 C] ─┘                    |-- 主线程：accept 新连接
                                    |-- 每连接一个子线程：读取与处理
                                    +-- 内存态：users / sessions / rooms
```

### 4.2 逻辑架构

```
+-----------------------------------------------------------+
|                         客户端 (client)                    |
|  inputLoop（主线程）   readerLoop（读线程）   outLock        |
+---------------------------- TCP / JSON -------------------+
|                         服务端 (server)                    |
|  run/accept（主线程）  handleClient（每连接线程）  startSweeper |
|  +-----------------------------------------------------+  |
|  |  内存状态: users / sessions / rooms  (gLock 保护)     |  |
|  +-----------------------------------------------------+  |
+-----------------------------------------------------------+
```

### 4.3 技术选型

| 关注点 | 选型 | 理由 |
|---|---|---|
| 传输 | TCP（`stdx.net`） | 面向连接、可靠，实现简单 |
| 分帧 | 按行分隔 JSON | 无需手写长度前缀与拆包逻辑 |
| 编解码 | `stdx.encoding.json` | 标准库支持，字段直观 |
| 并发 | `spawn` + `Mutex` | 概念少，易理解 |
| 哈希 | `std.crypto.digest` SHA-256 + `std.random` 盐 | 标准库即可满足 |
| 时间 | `std.time.DateTime` | 生成消息时间戳 |
| 终端 | `std.console` 行输入 + 标准输出 | 无需 raw 模式 |
| 构建 | 单个 cjpm 工程 | 降低工程复杂度 |

> 精确导入路径（`stdx.net.*`、`stdx.encoding.json`）在 M0 阶段以实际 SDK 示例验证后固化。

### 4.4 模块划分

| 文件 | 职责 | 主要类型/函数 |
|---|---|---|
| `src/main.cj` | 入口与模式分派 | `main(args)` |
| `src/protocol.cj` | 消息编解码与字段常量 | `encode`、`decode`、`MSG_*` 常量 |
| `src/server.cj` | 服务端全部逻辑 | `Server`、`Session` |
| `src/client.cj` | 客户端全部逻辑 | `Client` |

### 4.5 运行时模型

| 进程 | 线程 | 职责 | 生命周期 |
|---|---|---|---|
| server | 主线程 | accept 循环 | 进程期 |
| server | 连接线程 ×N | 读取/处理/回复该连接 | 连接期 |
| server | 巡检线程 | 心跳超时清理 | 进程期 |
| client | 主线程 | 读取输入并发送 | 进程期 |
| client | 读线程 | 接收并打印 | 连接期 |

### 4.6 并发与同步设计

- **全局锁 `gLock`**：保护 `users`、`sessions`、`rooms` 三个容器。
- **每会话写锁 `writeLock`**：保护该连接 socket 的写操作。
- **锁顺序**：若同时需要两把锁，**必须先 `gLock` 后 `writeLock`**，严禁反向，避免死锁。
- **持锁原则**：锁内只做内存操作，**禁止在持锁期间做阻塞 I/O**；
  广播时先在锁内收集目标会话列表，再释放锁逐一会话加写锁发送。
- **输出锁 `outLock`**（客户端）：保护终端输出，防止两线程打印交错。

### 4.7 目录结构

```
lanchat/
├── cjpm.toml          # 工程配置
├── src/
│   ├── main.cj        # 入口：server / client
│   ├── protocol.cj    # 消息定义 + 编解码
│   ├── server.cj      # 服务端
│   └── client.cj      # 客户端
└── docs/
    ├── README.md                  # 入口
    ├── DEVELOPMENT.md             # 本文档
    ├── DEPENDENCIES.md            # 依赖库
    ├── MINIMAL_IMPLEMENTATION.md  # 最小实现（框架）
    ├── IMPLEMENTATION_PLAN.md     # 完整实现方案
    ├── IMPLEMENTATION_PROCESS.md  # 实现流程
    └── DEVELOPMENT_TESTING.md     # 开发与测试
```

---

## 5. 通信协议规范

### 5.1 传输与分帧

- 底层：TCP，服务端默认监听 `0.0.0.0:9000`。
- 分帧：**一行一条 JSON**，以 `\n`（LF, 0x0A）结尾。
- 发送：`encode` 生成 JSON 字符串并追加 `\n` 后写出。
- 接收：从 socket 逐字节读取直到 `\n`，得到一行（不含 `\n`）。
- 限制：单行长度 **≤ 64 KiB**；超过则服务端关闭该连接（错误码 `1006`）。
- 空行（仅 `\n`）应被忽略，不计为错误。

### 5.2 编码

- 字符集：UTF-8。
- 数据格式：JSON 对象，字段扁平化（不使用嵌套 `data`）。
- 时间：`ts` 为 Unix 秒级时间戳，`int64`。

### 5.3 消息通用结构

每个消息是 JSON 对象，`type` 为必填字符串，其余字段依类型而定。

```json
{"type":"<消息类型>", "<字段>":"<值>"}
```

### 5.4 客户端 → 服务端消息

| 消息 | 必填字段 | 可选字段 | 语义 | 成功响应 | 失败 |
|---|---|---|---|---|---|
| `register` | `username`, `password` | — | 注册新账号 | `ok(action=register)` | `1002/1006` |
| `login` | `username`, `password` | — | 登录 | `login_ok` | `1003/1006` |
| `list_rooms` | — | — | 列出房间 | `room_list` | `1001` |
| `create_room` | `room` | — | 创建房间 | `ok(action=create_room)` | `1001/1006` |
| `join_room` | `room` | — | 加入/切换房间 | `ok(action=join_room)` | `1001/1004` |
| `leave_room` | `room` | — | 离开房间 | `ok(action=leave_room)` | `1001/1004` |
| `who` | — | `room` | 查询在线成员 | `user_list` | `1001` |
| `send_room` | `room`, `text` | — | 房间群聊 | 广播 `message` | `1001/1004/1006` |
| `send_private` | `to`, `text` | — | 私聊 | 定向 `message` | `1001/1005/1006` |
| `ping` | — | — | 心跳 | `pong` | — |

### 5.5 服务端 → 客户端消息

| 消息 | 字段 | 语义 |
|---|---|---|
| `ok` | `action:string` | 通用成功应答 |
| `error` | `code:int`, `message:string` | 错误 |
| `login_ok` | `username:string`, `rooms:string[]` | 登录成功 |
| `room_list` | `rooms:string[]` | 房间名列表 |
| `message` | `scope:"room"\|"private"`, `room?:string`, `from:string`, `to?:string`, `text:string`, `ts:int64` | 聊天消息 |
| `system` | `text:string`, `ts:int64` | 系统通知 |
| `user_list` | `room:string`, `users:string[]` | 在线成员 |
| `pong` | — | 心跳应答 |

### 5.6 连接状态机

```
                register / login
[已连接未认证] ─────────────────► [已认证]
      ▲                              │  ▲
      │ login 失败 / 协议错误         │  │ leave_room
      │                              ▼  │
      │                          [在房间中]
      │                              │
      └────────── 连接关闭 ──────────┘
```

约束：

- `register/login/ping` 允许在“未认证”状态发送。
- 其余消息 MUST 处于“已认证”状态，否则返回 `1001`。
- 加入房间即从旧房间离开；重复加入同一房间返回 `ok` 且不重复广播。

### 5.7 时序

注册：

```
Client                          Server
  |-- register(username,pw) ------>|
  |<-- ok(action=register) --------|  或 error(1002)
```

登录：

```
Client                          Server
  |-- login(username,pw) --------->|
  |<-- login_ok(username,rooms) ---|  或 error(1003)
```

群聊：

```
ClientA            Server                 ClientB (同房间)
  |-- send_room ----->|                       |
  |<-- ok? -----------|                       |
  |                   |-- message(scope=room) -->|
```

私聊：

```
ClientA            Server                 ClientB (在线)
  |-- send_private:to=B -->|                   |
  |<-- message(scope=private) --|             |
  |                        |-- message(...) ---->|
```

心跳与超时：

```
Client                         Server
  |-- ping ----------------------->|
  |<-- pong -----------------------|
  ... 若 90s 无任何消息 ...
                                巡检线程：关闭连接 + 广播离开
```

### 5.8 错误码

| code | 名称 | 触发条件 |
|---|---|---|
| 1001 | NOT_AUTHENTICATED | 未登录即发送受限消息 |
| 1002 | USERNAME_TAKEN | 注册时用户名已存在 |
| 1003 | BAD_CREDENTIALS | 用户名或密码错误 |
| 1004 | ROOM_NOT_FOUND | 加入/发送到不存在的房间 |
| 1005 | USER_OFFLINE | 私聊目标不在线 |
| 1006 | PROTOCOL_ERROR | JSON 非法、字段缺失、超长、非法字符 |
| 1099 | INTERNAL_ERROR | 未预期异常 |

### 5.9 字段校验规则

| 字段 | 规则 |
|---|---|
| `username` | 长度 3–16，仅 `[A-Za-z0-9_]`，唯一 |
| `password` | 长度 6–64，允许可见 ASCII |
| `room` | 长度 1–32，仅 `[A-Za-z0-9_-]` |
| `text` | 长度 1–2000 字符，去除首尾空白后非空 |
| 整行 | ≤ 64 KiB |

违反校验规则返回 `1006`（注册/登录字段可在认证前校验并返回相应错误）。

### 5.10 版本与兼容

- 本版本协议标识为 v1（消息中暂不含版本字段，后续如需可加 `v`）。
- 协议扩展应保持向后兼容：新增可选字段、新增消息类型。
- 删除/改名已有字段或语义为破坏性变更，需升级版本并同步文档与代码。

---

## 6. 数据设计

### 6.1 实体关系

```
User (name) 1 ─── 0..1 Session     // 同一用户名最多一个活跃会话
Room (name) 1 ─── *  members       // 成员为用户名
Session     * ─── 0..1 Room        // 每会话至多一个当前房间
```

### 6.2 数据结构

```
User {
  name: String          // 唯一
  salt: String          // 十六进制随机盐
  hash: String          // SHA256(salt + password) 十六进制
}

Session {
  name: String
  socket: TcpSocket
  room: ?String         // None 表示未加入房间
  lastSeen: MonoTime    // 最近收到消息的时间
  writeLock: Mutex      // 保护 socket 写
}

Room {
  name: String
  members: ArrayList<String>   // 成员用户名
}
```

### 6.3 全局状态

| 容器 | 类型 | 键 | 保护 |
|---|---|---|---|
| `users` | `HashMap<String, User>` | 用户名 | `gLock` |
| `sessions` | `HashMap<String, Session>` | 用户名 | `gLock` |
| `rooms` | `HashMap<String, Room>` | 房间名 | `gLock` |

启动时创建默认房间 `general`。

### 6.4 密码存储

1. 注册：`salt = randomHex(16)`；`hash = SHA256(salt + password)`。
2. 存储 `salt`、`hash`，**不存明文**。
3. 登录：用存储的 `salt` 重算 `hash` 并比较，采用定长比较。
4. 对比失败统一返回 `1003`，不区分“用户不存在/密码错误”。

### 6.5 数据不变量

| 编号 | 不变量 |
|---|---|
| INV-1 | `users` 中用户名唯一 |
| INV-2 | `Room.members` 中的每个名字必须存在于 `sessions` |
| INV-3 | `Session.room` 非空时，该房间的 `members` 必包含此会话名 |
| INV-4 | `sessions` 中每个名字必存在于 `users` |

### 6.6 生命周期与清理

会话结束（正常退出或断线）时执行 `cleanup(session)`：

1. 若 `session.room` 非空，从该房间 `members` 移除，并向其余成员广播 `system` 离开通知。
2. 从 `sessions` 移除。
3. 关闭 socket。
4. 空房间处理：除 `general` 外的空房间 MAY 删除；`general` 始终保留。

---

## 7. 详细设计

### 7.1 protocol.cj

| 函数 | 签名（约定） | 说明 |
|---|---|---|
| `encode` | `func encode(o: JsonObject): String` | 序列化并追加 `\n` |
| `decode` | `func decode(line: String): Option<JsonObject>` | 解析一行；失败返回 `None` |
| `newMsg` | `func newMsg(typ: String): JsonObject` | 新建含 `type` 的对象 |
| 写入辅助 | `putStr` / `putInt` / `putStrArray` | 向对象写入字符串、整数、字符串数组 |
| 读取辅助 | `getStr` / `getOptStr` / `getInt` / `getStrArray` | 从对象读取字段，缺失按约定处理 |
| `readLine` | `func readLine(sock: TcpSocket): Option<String>` | 读到 `\n`；关闭返回 `None` |
| `writeLine` | `func writeLine(sock: TcpSocket, text: String): Bool` | 写出 `text + "\n"` |
| 字段校验 | `validUsername` / `validPassword` / `validRoom` / `validText` | 返回 `Bool` |
| 消息构造 | `okMsg` / `errMsg` / `systemMsg` / `chatMsg` | 返回 `JsonObject` |
| `nowSeconds` | `func nowSeconds(): Int64` | 当前 Unix 秒 |

消息类型以顶层字符串常量 `MSG_*` 集中定义，错误码以 `ERR_*`、限制值以常量定义，避免散落硬编码。

> 说明：JSON 具体 API 名称以实际 SDK 为准；M0 阶段以官方示例确认后固化。

### 7.2 server.cj

**类型**

- `Session`：见 §6.2。
- `Server`：持有 `users / sessions / rooms / gLock / port`。

**主要函数**

| 函数 | 说明 |
|---|---|
| `run()` | 创建监听、进入 accept 循环、启动巡检线程 |
| `handleClient(sock)` | 逐行读取、解码、`dispatch`；结束调用 `cleanup` |
| `dispatch(sess, msg)` | 认证态检查 + 按 `type` 分发 |
| `handleRegister/handleLogin` | 认证相关 |
| `handleListRooms/handleCreateRoom/handleJoinRoom/handleLeaveRoom/leaveCurrentRoom` | 房间相关 |
| `handleWho` | 查询房间在线成员 |
| `handleSendRoom/handleSendPrivate` | 消息相关 |
| `send(sess, msg)` | 持 `writeLock` 写出一行 |
| `broadcast(room, msg)` | 锁内收集成员 → 释放 `gLock` → 逐个 `send` |
| `cleanup(sess)` | 见 §6.6 |
| `startSweeper()` | 周期检查 `lastSeen`，关闭超时会话 |

**核心伪代码**

```
func run():
    listener = 创建监听(0.0.0.0, port)
    startSweeper()
    while running:
        sock = listener.accept()
        spawn { handleClient(sock) }

func handleClient(sock):
    sess = Session(socket=sock)
    while true:
        line = readLine(sock)
        if line == null: break           // 对端关闭
        if line.isEmpty(): continue      // 忽略空行
        if line.size > MAX_LINE: send error 1006; break
        obj = try decode(line) catch { send error 1006; continue }
        dispatch(sess, obj)              // 更新 sess.lastSeen
    cleanup(sess)

func broadcast(room, obj):
    targets = []
    gLock.lock()
    if room in rooms:
        for name in rooms[room].members:
            if name in sessions: targets.add(sessions[name])
    gLock.unlock()
    for s in targets: send(s, obj)
```

### 7.3 main.cj

```
func main(args):
    if args.size < 2: printUsage(); return
    match args[1]:
        case "server": Server(parsePort(args, 2)).run()
        case "client":
            if args.size < 3: 报错缺少主机; return
            Client(args[2], parsePort(args, 3)).run()
        case _: printUsage()
```

### 7.4 配置项

| 端 | 配置 | 来源 | 默认 |
|---|---|---|---|
| server | 监听地址 | 代码常量 | `0.0.0.0` |
| server | 端口 | 命令行 `/` 常量 | `9000` |
| client | 主机 IP | 命令行参数 | 无（必填） |
| client | 端口 | 命令行参数 | `9000` |

---

## 8. 客户端设计

### 8.1 界面模型

采用“滚动式”终端界面：收到消息即追加一行，输入区显示 `> ` 提示符。

```
已连接到 192.168.1.10:9000
[10:31] * 你加入了 general
[10:32] <alice> hello everyone
[10:32] <bob> hi alice
[10:32] [私聊]<bob> psst
> 
```

### 8.2 显示格式规范

| 类别 | 格式 | 示例 |
|---|---|---|
| 房间消息 | `[HH:MM] <name> text` | `[10:32] <alice> hi` |
| 私聊消息 | `[HH:MM] [私聊]<name> text` | `[10:32] [私聊]<bob> psst` |
| 系统消息 | `[HH:MM] * text` | `[10:31] * bob 加入了 general` |
| 错误 | `[错误] message` | `[错误] 用户名或密码错误` |

### 8.3 命令集

| 命令 | 等价消息 | 说明 |
|---|---|---|
| `/join <room>` | `join_room` | 加入/切换房间 |
| `/rooms` | `list_rooms` | 列出房间 |
| `/who` | `who` | 当前房间在线成员 |
| `/msg <user> <text>` | `send_private` | 私聊 |
| `/quit` | （断开） | 退出 |
| 其它文本 | `send_room` | 发送到当前房间 |

### 8.4 线程模型

- **主线程**：读入一行 → 解析命令/消息 → `send`。
- **读线程**：循环读服务端消息 → 格式化 → 打印。
- **outLock**：两线程打印均需持有，保证整行原子输出。
- 未登录前，主线程先完成注册/登录交互再进入消息循环。

### 8.5 客户端异常处理

| 情形 | 处理 |
|---|---|
| 连接失败 | 提示检查 IP/端口/防火墙/同一 WiFi，退出 |
| 服务端 `error` | 打印 `[错误]` 信息 |
| 连接断开 | 打印提示并退出 |
| 非法输入行 | 本地提示，不发送 |

---

## 9. 安全设计

### 9.1 认证

- 登录成功即建立会话；后续消息以会话身份处理，不再重复校验密码。
- 未认证连接仅允许 `register/login/ping`。

### 9.2 密码存储

- 加盐 SHA-256，杜绝明文与彩虹表。
- 生产环境建议升级为 PBKDF2/bcrypt（超出 v1.0 范围）。

### 9.3 输入校验与健壮性

- 严格按 §5.9 校验字段，非法输入返回 `1006` 并记录。
- 单行上限 64 KiB，防止内存耗尽。
- 单个连接异常只影响该连接（失败隔离）。

### 9.4 已知限制

- 链路明文传输，局域网内可被嗅探（v1.0 接受）。
- 无速率限制、无登录失败锁定（后续版本考虑）。

---

## 10. 开发规范

### 10.1 命名

| 类别 | 规则 | 示例 |
|---|---|---|
| 包名 / 文件名 | 小写下划线 | `protocol.cj` |
| 类型 | UpperCamel | `Session` |
| 函数 / 变量 | lowerCamel | `handleLogin` |
| 常量 | 全大写下划线 | `MAX_LINE` |
| 消息类型 | 小写下划线字符串 | `"send_room"` |

### 10.2 代码风格

- 函数单一职责，建议 ≤ 50 行；文件 ≤ 约 400 行。
- 提交前执行 `cjfmt`、`cjlint`。
- 不引入未使用的依赖与死代码。

### 10.3 错误处理

- 协议错误转为 `error` 消息；不向客户端暴露堆栈。
- 内部异常捕获后返回 `1099`，并记录日志到控制台。
- 不使用“吞异常”式空 `catch`。

### 10.4 注释

- 仅注释“为什么”，不注释“是什么”。
- 公共函数与复杂分支应有简短说明。

### 10.5 提交规范

`<type>(<scope>): <subject>`，type ∈ {feat, fix, docs, refactor, test, chore}。

```
feat(server): broadcast room messages to members
fix(protocol): reject over-length lines
docs(protocol): clarify error code 1005
```

### 10.6 分支策略

| 分支 | 用途 |
|---|---|
| `main` | 始终可编译、可测试 |
| `feature/*` | 新功能 |
| `fix/*` | 缺陷修复 |
| `docs/*` | 文档 |

禁止直接向 `main` 推送未验证代码。

### 10.7 评审清单

- [ ] 协议变更已同步 §5 与 `protocol.cj`
- [ ] 共享状态访问均持 `gLock`
- [ ] 写 socket 均持 `writeLock`
- [ ] 锁顺序为 `gLock` → `writeLock`
- [ ] 无持锁阻塞 I/O
- [ ] 输入已按 §5.9 校验
- [ ] 密码无明文
- [ ] 通过 `cjfmt` 与 `cjlint`

---

## 11. 开发流程

```
需求/文档 ──► 协议先行 ──► 编码 ──► 单元测试 ──► 本地联调 ──► 提交/评审 ──► 合并
```

标准循环（以“房间广播”为例）：

1. 更新 §5 协议（如有变化）。
2. 修改 `protocol.cj` 定义常量与编解码。
3. 编写/更新单元测试。
4. 实现 `server.cj` 路由与广播。
5. 实现 `client.cj` 发送与展示。
6. 本地多终端联调。
7. `cjfmt`、`cjlint`、`cjpm test`。
8. 提交并评审合并。

---

## 12. 测试方案

### 12.1 测试策略

| 层次 | 范围 | 手段 |
|---|---|---|
| 单元测试 | 协议编解码、校验、哈希 | `std.unittest` |
| 集成测试 | 注册→登录→房间→收发 | 测试客户端脚本 |
| 验收测试 | FR/NFR 全量 | 手工多终端 + 检查表 |

### 12.2 单元测试用例

| 用例 | 输入 | 预期 |
|---|---|---|
| UT-01 编码 | `{type:ok,action:register}` | 以 `\n` 结尾的合法 JSON |
| UT-02 解码 | 合法一行 | 对象含 `type` |
| UT-03 非法 JSON | `{bad` | 抛异常/返回错误 |
| UT-04 超长行 | > 64 KiB | 判定为 `1006` |
| UT-05 哈希一致 | 同盐同密码 | 结果相同 |
| UT-06 哈希校验 | 错误密码 | 校验失败 |
| UT-07 用户名校验 | `ab`、`a b`、`a#b` | 拒绝 |
| UT-08 房间名校验 | 空、含空格 | 拒绝 |
| UT-09 文本校验 | 空、纯空白、超长 | 拒绝 |
| UT-10 命令解析 | `/msg bob hello world` | 解析出目标与正文 |

### 12.3 集成测试用例

| 用例 | 步骤 | 预期 |
|---|---|---|
| IT-01 | A 注册并登录 | 收到 `login_ok` |
| IT-02 | B 注册并登录 | 收到 `login_ok` |
| IT-03 | A、B 加入 general | 双方收到加入通知 |
| IT-04 | A 发送房间消息 | B 收到 `message(scope=room)` |
| IT-05 | A 私聊 B | 仅 B 收到；C 收不到 |
| IT-06 | A 私聊离线用户 | 收到 `1005` |
| IT-07 | 关闭 B | A 收到离开系统通知 |
| IT-08 | 心跳超时 | 服务端清理并广播 |
| IT-09 | 发送畸形 JSON | 该连接收到 `1006`，服务端存活 |

### 12.4 验收对照

| 需求 | 验收方式 |
|---|---|
| FR-1、FR-2 | IT-01、IT-02 |
| FR-3、FR-4 | IT-03、IT-04 |
| FR-5 | IT-05、IT-06 |
| FR-6 | IT-03、IT-07 |
| FR-7 | IT-08 |
| FR-8 | 三终端手工联调 |
| NFR-1 | UT-04 |
| NFR-4 | IT-09 |

### 12.5 测试矩阵

| 场景 | 单机 | 双机 | 三机 |
|---|---|---|---|
| 注册/登录 | 是 | 是 | 是 |
| 群聊/私聊 | 是 | 是 | 是 |
| 断线清理 | 是 | 是 | 是 |
| 心跳超时 | 是 | 否 | 否 |

---

## 13. 部署与运行

### 13.1 环境要求

| 项 | 要求 |
|---|---|
| 操作系统 | Windows 10/11 或 Windows Server |
| 工具链 | 仓颉 SDK（含 `cjc`、`cjpm`）+ Visual Studio 生成工具 |
| 网络 | 所有设备连接同一 WiFi，处于同一子网 |
| 端口 | 默认 TCP 9000，需在主机放行 |

### 13.2 主机配置步骤

1. 连接 WiFi，`ipconfig` 查看并记录 IPv4 地址（如 `192.168.1.10`）。
2. 启动服务端：

   ```powershell
   cjpm run -- server
   ```

3. 放行防火墙入站 TCP 9000（首次会弹窗选择允许“专用网络”）：

   ```powershell
   netsh advfirewall firewall add rule name="LANChat-9000" dir=in action=allow protocol=TCP localport=9000
   ```

4. 关闭休眠/睡眠，保持主机在线。

### 13.3 终端配置步骤

1. 连接同一 WiFi。
2. 启动客户端：

   ```powershell
   cjpm run -- client 192.168.1.10 9000
   ```

3. 连通性自测：

   ```powershell
   ping 192.168.1.10
   Test-NetConnection 192.168.1.10 -Port 9000
   ```

### 13.4 网络注意事项

| 事项 | 说明 |
|---|---|
| 同子网 | IP 前三段相同 |
| AP 隔离 | 访客 WiFi / 客户端隔离会阻断互访，需关闭 |
| 动态 IP | DHCP 可能变化，建议路由器绑定静态 IP |
| 双频段 | 同一 WiFi 的 2.4G/5G 通常互通 |

### 13.5 故障排查

| 现象 | 排查 |
|---|---|
| 连接被拒绝 | 服务端未启动 / 端口不对 / IP 不对 |
| 连接超时 | 不同子网 / AP 隔离 / 防火墙未放行 |
| 登录失败 | 密码错误或未注册 |
| 消息乱序/截断 | 检查是否按行分帧、是否处理超长行 |
| 服务端无响应 | 查看是否发生死锁（锁顺序）或崩溃堆栈 |

---

## 14. 开发计划

### 14.1 里程碑

| 阶段 | 交付物 | 验收标准 |
|---|---|---|
| **M0 环境与校准** | 工具链 + stdx + 官方示例 | `cjc`/`cjpm` 可用，TCP/JSON 示例运行成功 |
| **M1 框架搭建** | 四文件骨架：常量、数据模型、函数签名 | 结构完整、签名齐全、与协议文档一致（见 `MINIMAL_IMPLEMENTATION.md`） |
| **M2 基础实现** | `protocol.cj`、`server.cj`、`client.cj` 核心逻辑 | 两终端可注册、登录、在 `general` 群聊 |
| **M3 多房间与私聊** | 房间管理、私聊、在线列表 | 两终端可切换房间、私聊、`/who` |
| **M4 健壮性与交付** | 心跳、校验、测试、README | `cjpm test` 通过，三机联调通过 |

### 14.2 任务分解（WBS）

**M0 环境与校准**
- [ ] 安装仓颉工具链（含 VS 生成工具）
- [ ] 配置 stdx，确认 `stdx.net.*`、`stdx.encoding.json` 路径（见 `DEPENDENCIES.md`）
- [ ] 跑通官方 TCP 与 JSON 示例

**M1 框架搭建**
- [ ] 建立四文件骨架与 `cjpm.toml`
- [ ] 定义协议常量、错误码、限制值
- [ ] 定义数据模型字段与全部函数签名（TODO 占位）
- [ ] 与 §5、§6 核对一致

**M2 基础实现**
- [ ] `protocol.cj`：`encode`/`decode`、`readLine`/`writeLine`、字段校验
- [ ] `server.cj`：监听、accept、逐行读取、注册/登录
- [ ] 单房间群聊广播与系统通知
- [ ] `client.cj`：连接、认证、读线程、输入循环与显示
- [ ] `main.cj`：参数解析可用

**M3 多房间与私聊**
- [ ] 房间：创建/加入/离开、房间列表
- [ ] 私聊与在线列表 `/who`
- [ ] 客户端命令 `/join`、`/rooms`、`/msg`

**M4 健壮性与交付**
- [ ] 心跳（客户端 ping）与超时清理
- [ ] 字段校验完善、超长行拒绝、错误码覆盖
- [ ] 单元测试（编解码、校验、哈希）与集成用例
- [ ] README 与运行说明
- [ ] 三机 WiFi 联调

### 14.3 进度

- [x] 规划与文档
- [ ] M0 环境与校准
- [x] M1 框架搭建
- [ ] M2 基础实现
- [ ] M3 多房间与私聊
- [ ] M4 健壮性与交付

### 14.4 完成定义（DoD）

- FR-1..FR-10 实现并通过验收
- NFR-1..NFR-7 满足
- 协议文档与代码一致
- 无明文密码、无跨线程裸写 socket、无持锁阻塞 I/O
- 三机 WiFi 联调通过

---

## 15. 风险与应对

| 编号 | 风险 | 概率 | 影响 | 应对 |
|---|---|---|---|---|
| R-1 | stdx 导入路径不确定 | 中 | 高 | M0 先跑官方示例；网络/JSON 集中于 `protocol.cj` |
| R-2 | Windows 工具链/版本不兼容 | 中 | 高 | 使用官方支持版本并安装 VS 生成工具 |
| R-3 | 全局锁在人多时性能下降 | 低 | 中 | v1 接受；必要时按房间细分锁 |
| R-4 | 死锁 | 低 | 高 | 统一锁顺序，锁内禁止阻塞 I/O |
| R-5 | 明文传输被嗅探 | 中 | 中 | v1 接受；v2 引入加密 |
| R-6 | 访客 WiFi / AP 隔离 | 中 | 高 | 用普通 WiFi 或关闭客户端隔离 |
| R-7 | 主机 IP 变化 | 中 | 中 | 路由器绑定静态 IP，启动打印 IP |
| R-8 | 主机休眠导致掉线 | 中 | 高 | 关闭休眠，保持在线 |
| R-9 | 超长/畸形消息导致崩溃 | 低 | 高 | 行上限 + 严格校验 + 失败隔离 |
| R-10 | 客户端输出交错 | 中 | 低 | 使用 `outLock` 保护打印 |

---

## 16. 附录

### A. 消息示例全集

```
{"type":"register","username":"alice","password":"secret123"}
{"type":"ok","action":"register"}

{"type":"login","username":"alice","password":"secret123"}
{"type":"login_ok","username":"alice","rooms":["general"]}

{"type":"list_rooms"}
{"type":"room_list","rooms":["general","dev"]}

{"type":"create_room","room":"dev"}
{"type":"ok","action":"create_room"}

{"type":"join_room","room":"general"}
{"type":"system","text":"alice 加入了 general","ts":1730000000}

{"type":"who"}
{"type":"user_list","room":"general","users":["alice","bob"]}

{"type":"send_room","room":"general","text":"hello"}
{"type":"message","scope":"room","room":"general","from":"alice","text":"hello","ts":1730000001}

{"type":"send_private","to":"bob","text":"hi"}
{"type":"message","scope":"private","from":"alice","to":"bob","text":"hi","ts":1730000002}

{"type":"leave_room","room":"general"}
{"type":"ok","action":"leave_room"}
{"type":"system","text":"alice 离开了 general","ts":1730000003}

{"type":"ping"}
{"type":"pong"}

{"type":"send_private","to":"ghost","text":"hi"}
{"type":"error","code":1005,"message":"user offline"}
```

### B. 错误码速查

| code | 含义 | 典型处理 |
|---|---|---|
| 1001 | 未登录 | 先登录 |
| 1002 | 用户名已存在 | 更换用户名 |
| 1003 | 用户名或密码错误 | 重新输入 |
| 1004 | 房间不存在 | 先创建 |
| 1005 | 用户不在线 | 稍后再试 |
| 1006 | 协议错误/超长 | 检查客户端实现 |
| 1099 | 服务器内部错误 | 查看服务端日志 |

### C. 初学者指引

**阅读顺序**：§1–§6 建立概念 → `protocol.cj` → `server.cj` → `client.cj`。

**编码顺序**：
1. 官方 TCP 示例跑通连接。
2. 写 `protocol.cj` 并用单测验证。
3. 服务端“注册/登录”最小闭环。
4. 房间与广播。
5. 客户端收发。
6. 私聊、心跳、错误处理。

**服务端骨架**：

```
func runServer():
    server = TcpServerSocket("0.0.0.0", 9000)
    while true:
        client = server.accept()
        spawn { handleClient(client) }

func handleClient(socket):
    session = null
    while true:
        line = readLine(socket)
        if line == null: break
        if line.isEmpty(): continue
        handle(decode(line))
    cleanup(session)
```

**常见坑**：
- 忘记加 `gLock` → 并发修改 `HashMap` 出错。
- 持锁写 socket → 慢客户端拖住全局，甚至死锁。
- 未按 `\n` 分帧 → 消息粘连或截断。
- 私聊按用户名查 `sessions` 前未判空 → 崩溃。

### D. 变更记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v0.1 | 2026-09-18 | 初稿 |
| v0.2 | 2026-09-18 | 精简架构，面向初学者 |
| v1.0 | 2026-09-18 | 专业详细化，补齐规范与验收 |
