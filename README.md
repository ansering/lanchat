# LAN Chat
本仓库仅作为软件工程课程学习使用

仓颉语言局域网聊天课程设计。计划由服务端预建账号并转发公共频道消息和私信；文件与图片传输为选做。当前仓库是程序骨架，尚不能运行聊天。

从 [docs/README.md](docs/README.md) 开始阅读：其中链接到[开发需求介绍](docs/DEVELOPMENT_REQUIREMENTS.md)、[开发方案](docs/DEVELOPMENT_PLAN.md)和[各阶段验收方案](docs/STAGE_ACCEPTANCE.md)。

组员使用 Git 和 GitHub 提交改动前，请阅读[协作指南](CONTRIBUTING.md)。

源码位于 `src/`，工程配置在 `cjpm.toml`。当前已安装仓颉 SDK 1.1.3，并在 Ubuntu 26.04 上编译运行 TCP 最小探针；已配置匹配 SDK 1.1.3 的 stdx 1.1.3.1，`cjpm check` 和 `cjpm build` 已通过；聊天逻辑仍为 TODO，联调尚未开始。
