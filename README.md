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

## 产品边界

FreeRAG app 只做本地原材料收集，不自动 OCR、不自动转写、不自动联网分析。MyRAG skill 负责读取本地语料、做多视角深挖、证据校准，并把处理结果写回 `processed/<entry_id>/`。

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
