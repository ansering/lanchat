# LAN Chat 文档导航

本目录只保留课程设计的四份文档。先确定需求，再按方案开发，每完成一阶段用验收方案记录证据。

| 文档 | 用途 |
|---|---|
| [开发需求介绍](DEVELOPMENT_REQUIREMENTS.md) | 项目目标、账号与公共频道概念、必做/选做需求和交付边界 |
| [开发方案](DEVELOPMENT_PLAN.md) | 架构、通信协议、模块职责、依赖安装、开发顺序与风险 |
| [各阶段验收方案](STAGE_ACCEPTANCE.md) | M0–M4 的入口条件、检查步骤、通过标准和证据；M5 为选做 |
| 本 README | 文档阅读顺序和当前状态 |

## 当前状态

- 仓库已有五个仓颉源文件；单频道状态和方法边界已整理，但大部分行为仍为 TODO，不能用于聊天。
- 当前开发环境为 Ubuntu 26.04、仓颉 SDK 1.1.3（`x86_64-unknown-linux-gnu`）和 stdx 1.1.3.1；TCP 最小探针、`cjpm check` 和 `cjpm build` 已通过。Windows 配置步骤已写入开发方案，但尚未在 Windows 机器验证；协议测试和局域网联调也尚未完成。
- 组员安装前请阅读 SDK 与 stdx 的配置、版本检查和常见问题，见[开发方案的环境校准章节](DEVELOPMENT_PLAN.md#4-依赖安装与环境校准m0)。
- 阶段进度以[各阶段验收方案](STAGE_ACCEPTANCE.md)的实际记录为准；目前没有阶段可标为通过。

项目入口和源码位置见[根目录 README](../README.md)。组员提交和审查改动的步骤见根目录[协作指南](../CONTRIBUTING.md)。
