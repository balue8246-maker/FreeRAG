# FreeRAG

FreeRAG 是一个原生 macOS 本地语料收集工具。它负责低成本收集屏幕、剪贴板和语音原材料，并写入 `~/Documents/Corpus/`。MyRAG skill 在 Codex / Claude Code 聊天里读取这些有限语料，去重、深挖，再按事项汇总给用户判断。

[English README](README.md)

## 它负责什么

- 把本地 raw 材料收进统一语料目录。
- App 本身保持轻：不默认联网分析、不默认 OCR、不默认转写。
- MyRAG 在聊天窗里读取本地语料，输出一事项一行的 summary 表格。
- 只有用户看过 summary 并确认 raw 已接盘后，才标记 raw 可清理。

## 产品边界

FreeRAG 负责收。MyRAG 负责读和淘金。

FreeRAG 不会自行上传截图、剪贴板内容或录音。`~/Documents/Corpus/` 是用户本机语料，供用户在 Codex / Claude Code 里明确调用 MyRAG 时读取。

MyRAG 的输出以表格为主：一个事项一行，把事实、数字、人物/项目、判断、风险、下一步、证据和置信度合并到同一行。大量重复剪贴板图片必须先按 SHA-256 精确折叠，只读代表样本。

## 仓库结构

```text
FreeRAG/
  Packaging/                 原生 app 和 DMG 构建脚本
  Resources/Assets/           app 图标和状态栏图标
  Sources/main.swift          Swift/AppKit 主实现
shared/skills/myrag/          MyRAG skill 和本地语料辅助脚本
docs/                         产品文档、公开状态和产品介绍页
release/github/               GitHub 发布计划、清单、release notes
```

## 构建

```bash
FreeRAG/Packaging/build_native_app.sh
FreeRAG/Packaging/build_dmg.sh
```

本地构建产物进入 `dist/`。`dist/` 已被 Git 忽略；公开二进制包应该挂到 GitHub Releases，不应该长期提交进源码仓库。

当前版本：`0.5.0`，构建号 `2`。

## 安装

1. 从 GitHub Release 下载 DMG。
2. 把 `FreeRAG.app` 拖到 `/Applications`。
3. 从 `/Applications` 启动，保证 macOS 权限绑定到稳定位置。
4. 按需授予屏幕录制、辅助功能、麦克风权限。
5. 如需 LLM 侧语料淘金，把 DMG 里的 `myrag` skill 复制到 Codex / Claude Code skill 目录。

当前 beta 包是 ad-hoc signed，尚未公证，macOS 可能弹出 Gatekeeper 提示。

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

- [简体中文产品介绍](docs/product_overview.zh-CN.html)
- [英文产品介绍](docs/product_overview.en.html)

## 授权

MIT，见 [LICENSE](LICENSE)。
