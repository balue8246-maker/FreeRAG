# FreeRAG

FreeRAG 是一个很小的原生 macOS 菜单栏工具，把截图、剪贴板碎片和语音笔记变成本地语料库，供 Codex / Claude Code 这类 coding agent 后续检索和淘金。

它适合那些每天和 LLM 协作、但上下文散落在截图、浏览器标签、复制内容、会议笔记和半成形想法里的人。

[English README](README.md)

**Open Source Beta：** FreeRAG 通过 GitHub Releases 发布 DMG。当前 beta 尚未使用 Apple Developer ID 签名或公证，所以首次打开时 macOS 可能需要你到“系统设置 > 隐私与安全性”里手动允许。

<p>
  <a href="https://github.com/balue8246-maker/FreeRAG/releases/download/v0.5.1-beta.1/FreeRAG-0.5.1-build-3.dmg"><strong>下载 DMG</strong></a>
  ·
  <a href="docs/QUICKSTART.md">快速开始</a>
  ·
  <a href="docs/DEMO.md">演示流程</a>
  ·
  <a href="docs/FAQ.md">FAQ</a>
  ·
  <a href="https://github.com/balue8246-maker/FreeRAG/releases/latest">最新 Release</a>
  ·
  <a href="docs/LAUNCH_KIT.md">发布文案包</a>
</p>

![FreeRAG social preview](docs/assets/freerag_social_preview.png)

## 30 秒流程

1. 从菜单栏 HUD 收集屏幕、剪贴板或语音。
2. FreeRAG 把 raw 材料写入本地 `~/Documents/Corpus/`。
3. 在 Codex / Claude Code 里让 MyRAG 读取最近语料。
4. MyRAG 折叠重复材料、阅读代表证据，并返回“一事项一行”的表格。
5. 你决定哪些内容要变成工作日志、项目笔记，哪些 raw 可以清理。

## 下载

- [下载 DMG](https://github.com/balue8246-maker/FreeRAG/releases/download/v0.5.1-beta.1/FreeRAG-0.5.1-build-3.dmg)
- [最新 GitHub Release](https://github.com/balue8246-maker/FreeRAG/releases/latest)
- 当前 beta：`0.5.1`，构建号 `3`
- macOS app：Swift / AppKit，只驻留菜单栏

当前 beta 包使用本地自签稳定签名身份，尚未使用 Apple Developer ID 签名或公证，macOS 可能弹出 Gatekeeper 提示。

## 产品边界

FreeRAG 负责收。MyRAG 负责读和淘金。

FreeRAG 不会自行上传截图、剪贴板内容或录音。`~/Documents/Corpus/` 是用户本机语料，供用户在 Codex / Claude Code 里明确调用 MyRAG 时读取。

MyRAG 现在拆成两层：

- `SKILL.md`：日常运行时的语料淘金协议。
- `INSTALL_ADAPTERS.md`：一次性的模型/环境适配说明；当当前模型不能看图或不能转写音频时，用它配置 Vision / ASR 后端。

MyRAG 的输出以表格为主：一个事项一行，把事实、数字、人物/项目、判断、风险、下一步、证据和置信度合并到同一行。大量重复剪贴板图片必须先按 SHA-256 精确折叠，只读代表样本。

## 它负责什么

- 把本地 raw 材料收进统一语料目录。
- App 本身保持轻：不默认联网分析、不默认 OCR、不默认转写。
- MyRAG 在聊天窗里读取本地语料，输出一事项一行的 summary 表格。
- 把模型相关的图片 / 语音适配留在安装适配文档里，日常 skill 保持通用。
- 只有用户看过 summary 并确认 raw 已接盘后，才标记 raw 可清理。

## 仓库结构

```text
FreeRAG/
  CLI/                       给 agent / 脚本写入 corpus 的离线命令行工具
  Packaging/                 原生 app 和 DMG 构建脚本
  Resources/Assets/           app 图标和状态栏图标
  Sources/main.swift          Swift/AppKit 主实现
shared/skills/myrag/          MyRAG 运行时 skill 和本地语料辅助脚本
shared/skills/myrag/INSTALL_ADAPTERS.md
                              不同模型环境的图片 / 语音适配说明
docs/                         产品文档、公开状态和产品介绍页
release/github/               GitHub 发布计划、清单、release notes
```

## 构建

```bash
FreeRAG/Packaging/build_native_app.sh
FreeRAG/Packaging/build_dmg.sh
```

本地构建产物进入 `dist/`。`dist/` 已被 Git 忽略；公开二进制包应该挂到 GitHub Releases，不应该长期提交进源码仓库。

当前版本：`0.5.1`，构建号 `3`。

Developer ID 发布构建：

```bash
FreeRAG/Packaging/build_release_dmg.sh
```

该脚本会用 `Developer ID Application` 签名 `FreeRAG.app`，构建并签名 DMG，通过 `notarytool` 提交 Apple notarization，staple 票据，执行 Gatekeeper 校验，并更新本地 `.sha256` 文件。默认使用名为 `freerag-notary` 的 notary profile；也可以通过 `FREERAG_NOTARY_PROFILE` 指定。

## CLI

FreeRAG 也带一个轻量离线 CLI，给 agent 和脚本使用。它不控制正在运行的菜单栏 app，而是直接写入同一套本地 corpus 协议。

```bash
FreeRAG/CLI/freerag note "记录这段本地上下文"
FreeRAG/CLI/freerag note --stdin < notes.md
FreeRAG/CLI/freerag shot
FreeRAG/CLI/freerag image ./reference.png
FreeRAG/CLI/freerag voice ./recording.wav
FreeRAG/CLI/freerag list --limit 10
FreeRAG/CLI/freerag latest --open
```

`freerag shot` 调用 macOS 自带的 `screencapture`，所以屏幕录制权限属于运行 CLI 的终端或 agent 进程，不属于 `FreeRAG.app`。

可以设置 `FREERAG_CORPUS=/path/to/Corpus`，让 CLI 写入测试或脚本专用的非默认 corpus。

## 安装

1. 从 GitHub Release 下载 DMG。
2. 把 `FreeRAG.app` 拖到 `/Applications`。
3. 从 `/Applications` 启动，保证 macOS 权限绑定到稳定位置。
4. 如果 macOS 首次打开时拦截，到“系统设置 > 隐私与安全性 > 仍要打开”手动允许。
5. 按需授予屏幕录制、辅助功能、麦克风权限。
6. 如需 LLM 侧语料淘金，把 DMG 里的 `myrag` skill 复制到 Codex / Claude Code skill 目录。
7. 如果当前模型不能看图或不能转写录音，先按 `shared/skills/myrag/INSTALL_ADAPTERS.md` 配好 Vision / ASR。

## 本地语料目录

```text
~/Documents/Corpus/
  _index.json
  _library.json
  README_FOR_LLM.md
  screen/
  clipboard/
  voice/
  processed/
```

`processed/` 是可选处理层，只应该保存高密度摘要、工作日志、项目结论或已确认代表证据。MyRAG 不应该把几百个低价值 raw 变成几百个 processed 目录。

## 隐私

见 [PRIVACY.md](PRIVACY.md)。简短版：raw 证据默认只留在本地。不要提交或公开 corpus、截图、录音、转写、API key、团队/客户私密数据。

## 安全

见 [SECURITY.md](SECURITY.md)。

## 产品介绍

- [快速开始](docs/QUICKSTART.md)
- [演示流程](docs/DEMO.md)
- [FAQ](docs/FAQ.md)
- [简体中文产品介绍](docs/product_overview.zh-CN.html)
- [英文产品介绍](docs/product_overview.en.html)

## 授权

MIT，见 [LICENSE](LICENSE)。
