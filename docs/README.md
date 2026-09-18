# LAN Chat — 项目文档与代码框架

**基于仓颉语言的 WiFi 局域网聊天系统**

一台电脑作主机运行服务端，其余电脑作终端运行客户端，两端均使用仓颉实现。
目标平台为 Windows 10/11 或 Windows Server，所有节点处于同一 WiFi 局域网。

## 工程结构

```
lanchat/
├── cjpm.toml                      # 工程配置
├── src/
│   ├── main.cj                    # 入口：server / client 模式
│   ├── protocol.cj                # 消息定义 + 校验 + 编解码 + 分帧
│   ├── server.cj                  # 服务端（数据模型 + 业务逻辑）
│   └── client.cj                  # 客户端（认证 + 收发 + 命令）
└── docs/
    ├── README.md                  # 本文件
    ├── DEVELOPMENT.md             # 开发文档（总纲）
    ├── DEPENDENCIES.md            # 依赖库文档（std / stdx 配置）
    ├── MINIMAL_IMPLEMENTATION.md  # 最小系统实现方案
    ├── IMPLEMENTATION_PLAN.md     # 完整系统实现方案
    ├── IMPLEMENTATION_PROCESS.md  # 系统实现流程
    └── DEVELOPMENT_TESTING.md     # 开发与测试要求及方案
```

## 文档导航

| 文档 | 内容 |
|---|---|
| [DEVELOPMENT.md](./DEVELOPMENT.md) | 需求、架构、协议、数据、详细设计、安全、规范、测试、部署、风险 |
| [DEPENDENCIES.md](./DEPENDENCIES.md) | 标准库/stdx 依赖清单、下载与 `cjpm.toml` 配置、验证与排错 |
| [MINIMAL_IMPLEMENTATION.md](./MINIMAL_IMPLEMENTATION.md) | 端到端可运行的最小系统（Walking Skeleton） |
| [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md) | 迭代 I0–I4、模块要点、需求追踪矩阵 |
| [IMPLEMENTATION_PROCESS.md](./IMPLEMENTATION_PROCESS.md) | P0–P5 实现流程与各阶段 Gate |
| [DEVELOPMENT_TESTING.md](./DEVELOPMENT_TESTING.md) | 开发要求、质量门、测试用例、验收清单 |

## 代码框架状态

- 已搭建完整骨架：数据模型、消息分发、房间/私聊/心跳逻辑、客户端命令与显示。
- 标记 `TODO(M0)` 的位置依赖实际 SDK 的 stdx API（TCP 读写、JSON 访问、哈希/随机/时间）。
  **这些边界已集中隔离**，M0 阶段按官方示例校准即可，其余代码不受影响。
- 当前环境未安装仓颉工具链，代码**尚未编译验证**；完成 M0 后应以 `cjpm build` 为准。

### M0 校准清单

| 位置 | 依赖 |
|---|---|
| `protocol.cj` `readLine/writeLine` | `stdx.net` socket 读写 |
| `protocol.cj` `encode/decode` 及 `put*/get*` | `stdx.encoding.json` |
| `server.cj` `sha256Hex` | `std.crypto.digest` |
| `server.cj` `randomSalt` | `std.random` |
| `server.cj` `createListener` / `client.cj` `connectSocket` | `stdx.net` |
| `protocol.cj` `nowSeconds` / `client.cj` `formatTime` | `std.time` |
| `protocol.cj` `Console.readln`（client 使用） | `std.console` |

## 快速开始（M0 完成后）

```powershell
cjpm build
cjpm run -- server                 # 主机：默认端口 9000
cjpm run -- client 192.168.1.10    # 终端：连接主机
```

> 主机需在 Windows 防火墙放行入站 TCP 9000。

## 进度

- [x] 规划与文档
- [x] 代码基础框架
- [ ] M0 环境搭建与 API 校准
- [ ] M1 协议 + 服务端
- [ ] M2 客户端
- [ ] M3 联调与打磨
