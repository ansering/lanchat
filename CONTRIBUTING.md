# Git 与 GitHub 协作指南

本指南给第一次参加本项目开发的组员使用。项目仓库是 [ansering/lanchat](https://github.com/ansering/lanchat)；功能范围、开发顺序和验收标准分别见[开发需求介绍](docs/DEVELOPMENT_REQUIREMENTS.md)、[开发方案](docs/DEVELOPMENT_PLAN.md)和[各阶段验收方案](docs/STAGE_ACCEPTANCE.md)。下面的 Git 命令在 Linux 终端、Windows PowerShell 或 Git Bash 中均可使用；仓颉 SDK 的安装步骤另见开发方案。

## 1. 先理解四个词

| 词 | 在本项目中表示什么 |
|---|---|
| 仓库 | 保存源码、文档和提交历史的项目目录；GitHub 上也有一份远程仓库。 |
| 提交（commit） | 把一次有明确目的的改动记录到本地历史；提交后并不会自动上传。 |
| 分支（branch） | 独立开发一项任务的工作线，例如 `feature/login`。`main` 是集成后的主线。 |
| Pull Request（PR） | 在 GitHub 上提出“把我的分支合入 `main`”，供组员检查、讨论和合并。 |

日常流程是：**从最新 `main` 建分支 → 修改并检查 → 提交 → 推送分支 → 发起 PR → 组员审查后合并**。组内约定通过 PR 合并到 `main`，避免直接在 `main` 上开发。

## 2. 首次准备

1. 安装 [Git](https://git-scm.com/downloads)，注册并登录 [GitHub](https://github.com/)，确认 `git --version` 能显示版本号。
2. 告诉仓库负责人你的 GitHub 用户名。负责人在仓库的 **Settings → Collaborators → Add people** 邀请，组员接受邀请后才能直接推送到本仓库。仓库公开可读，不代表任何人都能直接推送；没有写入权限时使用下文的 Fork 流程。[GitHub 协作者说明](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/repository-access-and-collaboration/inviting-collaborators-to-a-personal-repository)
3. 在自己的电脑设置提交署名（填写自己的信息）：

   ```sh
   git config --global user.name "你的名字"
   git config --global user.email "你的 GitHub 邮箱"
   ```

   这两个值用于标识提交作者，**不是 GitHub 登录凭据**。不想公开私人邮箱时，可在 GitHub 邮箱设置中使用其提供的隐私邮箱地址。
4. 克隆仓库并进入目录：

   ```sh
   git clone https://github.com/ansering/lanchat.git
   cd lanchat
   git status
   ```

   `origin` 是本地仓库给远程仓库起的名字，可用 `git remote -v` 检查。首次克隆公开仓库可以直接用 HTTPS。推送时 GitHub 会要求认证：按提示使用浏览器或凭据管理器登录；GitHub 不接受账户密码作为 Git 的 HTTPS 密码。也可按[官方 SSH 指南](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)配置 SSH。不要把令牌、私钥或密码写进仓库、远程地址或截图。[GitHub HTTPS 认证说明](https://docs.github.com/en/authentication/securing-your-account-with-two-factor-authentication-2fa/accessing-github-using-two-factor-authentication)

## 3. 每项任务如何完成

先在组内确定任务范围，尽量让一个 PR 只解决一件事。协议字段、接口或依赖一旦变化，要同时通知负责服务端、客户端和测试的组员。

```sh
git switch main
git pull --ff-only origin main
git switch -c feature/login
```

把 `feature/login` 换成当前任务名，例如 `feature/protocol-json`、`fix/client-disconnect` 或 `docs/windows-setup`。修改文件后，先看改了什么：

```sh
git status
git diff
git diff --check
```

代码改动应按[开发方案](docs/DEVELOPMENT_PLAN.md)配置仓颉环境，并在当前阶段可运行时执行：

```sh
cjpm check
cjpm build
```

尚未实现的功能或尚未通过的阶段，需在 PR 中如实说明；编译通过不等于聊天功能已通过验收。提交时明确列出本次要上传的文件：

```sh
git add src/具体文件.cj docs/DEVELOPMENT_PLAN.md
git diff --cached
git commit -m "feat: implement login protocol"
git push -u origin feature/login
```

上面的 `git add` 文件名只是示例，**要替换成真实存在的文件**；可多次执行 `git add`。尽量避免直接 `git add .`，先检查是否混入构建产物、账号数据或无关修改。`git commit` 只记录在本地，`git push` 才上传到 GitHub。

推送后到仓库网页点击 **Compare & pull request**，目标分支选 `main`。PR 描述写清：改了什么、为什么改、如何检查、检查结果、仍有哪些 TODO；涉及协议或文档时附上相关变更。请另一名组员阅读代码并提出意见；修改后继续提交并推送同一分支，PR 会自动更新。审查完成再从 GitHub 页面合并。[GitHub PR 操作说明](https://docs.github.com/en/pull-requests/how-tos/create-pull-requests/creating-a-pull-request)

## 4. 其他人合并后，如何同步

开始新任务前，先更新 `main`。如果自己的任务分支还在开发中，也把最新 `main` 合入该分支：

```sh
git switch main
git pull --ff-only origin main
git switch feature/login
git merge main
git push
```

执行 `git pull` 或 `git switch` 前，先用 `git status` 确认未完成的修改已提交。遇到冲突时，Git 会列出冲突文件；打开文件，手工选择或整合 `<<<<<<<`、`=======`、`>>>>>>>` 两侧的内容，删除冲突标记，再执行：

```sh
git add 冲突文件
git commit
git push
```

处理后再次运行受影响的检查。不要用强制推送覆盖别人的提交；不确定如何解冲突时，把 `git status` 的输出和冲突文件发给组员一起看。

## 5. 没有写入权限时：Fork + PR

在原仓库网页点击 **Fork**，在自己的 GitHub 账号下创建副本，再克隆**自己的副本**。下面把 `你的用户名` 替换成实际 GitHub 用户名：

```sh
git clone https://github.com/你的用户名/lanchat.git
cd lanchat
git remote add upstream https://github.com/ansering/lanchat.git
git fetch upstream
git switch main
git merge --ff-only upstream/main
git switch -c feature/任务名
```

按第 3 节修改、检查和提交后，执行 `git push -u origin feature/任务名`。在 GitHub 上向 **`ansering/lanchat` 的 `main`** 发起 PR，来源选择自己的 Fork 和任务分支。之后同步原仓库时，用 `git fetch upstream` 和 `git merge --ff-only upstream/main` 更新自己的 `main`。[GitHub Fork PR 说明](https://docs.github.com/en/pull-requests/how-tos/create-pull-requests/creating-a-pull-request-from-a-fork)

## 6. 本项目提交前的检查

- 只提交当前任务需要的源码、配置和文档；提交前查看 `git status` 与 `git diff --cached`。
- `data/`（账号及运行数据）、`local-libs/`（本机 stdx）和 `target/`（构建产物）已被 `.gitignore` 排除。不要提交真实账号、密码、令牌或私钥。
- 修改协议、命令或安装步骤时同步更新文档；`docs/` 仍只保留现有四份文档。各阶段通过与否按[验收方案](docs/STAGE_ACCEPTANCE.md)记录证据。
- 在 PR 里说明 `cjpm check`、`cjpm build` 以及相关测试或手工联调的实际结果。不能运行时写明原因。

常用排查命令：`git status` 看当前分支及待提交文件，`git log --oneline -5` 看最近提交，`git diff --cached` 看已暂存内容。误暂存文件可用 `git restore --staged 文件名` 撤出暂存区，这不会删除文件内容。推送显示权限不足时检查邀请是否已接受、`git remote -v` 是否指向自己可写的仓库；显示远端有新提交时按第 4 节同步后再推送。
