# 依赖库文档

> 说明 LAN Chat 所需的标准库与 stdx 扩展库、获取方式、`cjpm.toml` 配置与验证步骤。

## 1. 依赖总览

| 依赖 | 类别 | 是否需额外安装 | 用途 | 使用位置 |
|---|---|---|---|---|
| `std.core` | 标准库 | 否（随 SDK） | 基础类型、Option、String 等 | 全部 |
| `std.collection` | 标准库 | 否 | `ArrayList`、`HashMap`、`StringBuilder` | `protocol/server/client` |
| `std.sync` | 标准库 | 否 | `Mutex`、`synchronized` | `server/client` |
| `std.time` | 标准库 | 否 | `DateTime`、`Duration`、时间戳 | `protocol/server/client` |
| `std.console` | 标准库 | 否 | 终端读写 | `client` |
| `std.random` | 标准库 | 否 | 盐值随机数 | `server` |
| `std.crypto.digest` | 标准库 | 否 | SHA-256 密码哈希 | `server` |
| `std.convert` | 标准库 | 否 | 字符串/数值转换 | `main/protocol` |
| `std.unittest` | 标准库 | 否 | 单元测试 | `tests/` |
| `stdx.net` | stdx 扩展 | **是** | TCP Socket（`TcpServerSocket`、`TcpSocket`） | `protocol/server/client` |
| `stdx.encoding.json` | stdx 扩展 | **是** | JSON 编解码 | `protocol` |
| `stdx.log`（可选） | stdx 扩展 | **是** | 结构化日志（v1 可用 `println` 替代） | `server/client` |

> 关键点：网络与 JSON 已从 SDK 迁移到 **stdx**，必须下载 stdx 二进制并在 `cjpm.toml` 中配置路径后才能编译。

## 2. 标准库依赖

`std.*` 包随仓颉 SDK 提供，**无需**在 `cjpm.toml` 中声明，直接在源码中 `import` 即可：

```cangjie
import std.collection.*
import std.sync.*
import std.time.*
import std.console.*
import std.random.*
import std.crypto.digest.*
```

## 3. stdx 依赖（必须配置）

### 3.1 下载 stdx 二进制（Windows）

先设置一次 PowerShell 执行策略（仅需一次，管理员窗口）：

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

下载指定版本到指定目录（**版本号需与 SDK 匹配**）：

```powershell
irm https://raw.gitcode.com/Cangjie/cangjie_stdx/raw/main/downloader.ps1 -OutFile "$env:TEMP\downloader.ps1"
& "$env:TEMP\downloader.ps1" 1.0.0.1 -p windows-x64 -d C:\cangjie_libs
```

参数说明：

| 参数 | 必选 | 说明 |
|---|---|---|
| `<版本号>` | 是 | 如 `1.0.0.1`，应与所用 SDK / stdx 版本对应 |
| `-p <平台-架构>` | 否 | Windows x64 为 `windows-x64`；省略则自动检测 |
| `-d <目录>` | 否 | 解压目标目录，默认当前目录 |

下载后目录形如：`<目录>\windows_x64_cjnative\stdx\...`，其下包含：

- `dynamic\stdx`：动态库（推荐，初学者优先）
- `static\stdx`：默认静态库
- `static-static-link-extern\stdx`：对外静态链接静态库

### 3.2 配置 `cjpm.toml`

在 `[target.<triple>]` 下通过 `path-option` 指向 stdx 二进制目录：

```toml
[target.x86_64-w64-mingw32]
  [target.x86_64-w64-mingw32.bin-dependencies]
    path-option = ["C:\\cangjie_libs\\windows_x64_cjnative\\stdx\\dynamic\\stdx"]
```

说明：

- `x86_64-w64-mingw32` 是 **Windows x64 的 target 三元组**，须与实际一致。
- `path-option` 指向 **`stdx` 目录本身**（如 `...\dynamic\stdx`），而非其上级。
- Windows 路径使用双反斜杠 `\\` 或正斜杠 `/`。

### 3.3 确认 target 三元组

执行 `cjc -v`，回显中的 `Target:` 即所需三元组：

```text
Cangjie Compiler: 1.0.0 (cjnative)
Target: x86_64-w64-mingw32
```

将 `cjpm.toml` 中的 `x86_64-w64-mingw32` 替换为实际值。

### 3.4 静态库链接注意事项（可选）

- 若使用 stdx 的**静态库**并涉及 `crypto` / `net`，Windows 需在 `compile-option` 追加 `-lcrypt32`：

  ```toml
  [package]
    compile-option = "-lcrypt32"
  ```

- stdx 依赖 **OpenSSL 3.x**；如走 TLS 能力需保证编译、链接、运行阶段 OpenSSL 版本一致。
- 本项目只使用明文 TCP，**推荐使用 `dynamic` 动态库**以简化链接。

## 4. 导入路径对照

| 能力 | 导入（以实际包名为准，见 M0 校准） | 使用位置 |
|---|---|---|
| TCP 服务端/客户端 | `import stdx.net.*` | `protocol.cj`（`readLine/writeLine`）、`server.cj`、`client.cj` |
| JSON | `import stdx.encoding.json.*` | `protocol.cj`（`encode/decode`、`put*/get*`） |
| 日志（可选） | `import stdx.log.*` | `server.cj`、`client.cj` |

> stdx 中网络包还包含 `stdx.net.http`、`stdx.net.tls` 等子包；
> 本项目仅用底层 Socket，具体子包名（如 `stdx.net` 或 `stdx.net.socket`）在 M0 以官方示例确认后固化。

## 5. 验证步骤

```powershell
# 1. 检查依赖是否可解析
cjpm check

# 2. 查看依赖树
cjpm tree

# 3. 编译
cjpm build

# 4. 运行
cjpm run -- server
```

出现 `can not find the following dependencies` 时，通常是 `path-option` 路径错误或 target 三元组不匹配。

## 6. 版本与兼容性

| 项 | 建议 |
|---|---|
| SDK 与 stdx 版本 | 保持一致；stdx 不承诺跨版本 API/ABI 兼容 |
| 锁定版本 | 提交 `cjpm.lock` 以保证可复现构建 |
| 升级 stdx | 执行 `cjpm update` 后重新 `cjpm build` 验证 |
| OpenSSL | 使用 `dynamic` stdx 时，运行环境需能加载同版本 OpenSSL 3.x（本项目明文 TCP 通常不触发） |

## 7. 常见问题

| 现象 | 原因 | 处理 |
|---|---|---|
| 找不到 `stdx.*` 包 | 未配置 stdx 依赖 | 检查 `cjpm.toml` 的 `path-option` |
| target 段未生效 | 三元组与 `cjc -v` 不一致 | 用实际 `Target:` 替换 |
| 链接报缺 OpenSSL/crypt32 符号 | 使用静态 stdx + crypto/net | 追加 `-lcrypt32`，或改用 `dynamic/stdx` |
| 运行时报找不到动态库 | 动态库不在搜索路径 | 将 stdx 动态库目录加入 `PATH` |
| 版本不兼容报错 | SDK 与 stdx 版本不匹配 | 下载与 SDK 对应的 stdx 版本 |

## 8. 依赖变更流程

1. 修改 `cjpm.toml` 或 `src` 中的 `import`。
2. 更新本文档第 1、4 节。
3. 如属协议/设计影响，同步更新 `DEVELOPMENT.md`。
4. 执行 `cjpm check`、`cjpm build`、`cjpm test` 验证。
