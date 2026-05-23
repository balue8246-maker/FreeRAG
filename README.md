# FreeRAG

FreeRAG 是一个原生 macOS 本地语料收集工具。它负责低成本收集屏幕、剪贴板和语音原材料，并把它们写入 `~/Documents/Corpus/`，供 MyRAG skill 后续检索、深挖和沉淀。

## 当前结构

- `FreeRAG/`：Swift/AppKit 原生 Mac app。
- `shared/skills/myrag/`：MyRAG skill，包含说明和检索脚本。
- `docs/`：当前 PRD、设计规范、质量标准和 HTML 产品说明。
- `dist/FreeRAG.app`：当前可测试 app。

## 构建

```bash
FreeRAG/Packaging/build_native_app.sh
```

构建产物：

```text
dist/FreeRAG.app
```

当前版本：`0.5.0`，构建号 `2`。版本号写在 `FreeRAG/Info.plist`：

- `CFBundleShortVersionString`：用户可见版本，例如 `0.4.0`。
- `CFBundleVersion`：构建号，每次发包递增。

升级时保持 `CFBundleIdentifier = com.acegent.freerag` 不变。macOS 权限主要跟 bundle id、签名身份和安装位置相关；只改版本号不应该要求用户重新授权。

## 产品边界

FreeRAG app 只做本地原材料收集，不自动 OCR、不自动转写、不自动联网分析。MyRAG skill 负责读取本地语料，处理图片/屏幕/音频信息，产出 OCR、转写、timeline、CSV 表格、多视角深挖和证据校准结果，并写回 `processed/<entry_id>/`。

MyRAG 确认某条原材料已经处理完成后，会写入 `_myrag_done.json` 标记。FreeRAG 原材料库里的“一键清理已处理过语料”只清理带标记的 raw 目录，并保留 `processed/` 里的沉淀结果。

对大量剪贴板图片，MyRAG 先用 `python3 shared/skills/myrag/scripts/myrag_search.py --image-clusters 40` 按 SHA-256 精确折叠重复图，再把代表样本交给视觉/OCR 子 agent。

核心语料目录：

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

## 文档

- `docs/PRODUCT_PRD.md`：当前产品定义和实现符合度。
- `docs/DESIGN_GUIDE.md`：界面和交互设计规范。
- `docs/QUALITY_BAR.md`：验收标准。
- `docs/product_overview.html`：可打开的产品说明页。
- `docs/CURRENT_STATE.md`：当前交接状态，供上下文恢复使用。
