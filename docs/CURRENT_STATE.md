# FreeRAG 当前状态交接

更新时间：2026-05-23

## 当前产品判断

FreeRAG 当前已经从“Windows/PySide 迁移项目”收敛为一个原生 macOS 小工具：

- **FreeRAG.app**：本地原材料收集器。
- **MyRAG skill**：本地 RAG 检索、归拢、多视角深挖、证据校准和收束出口。
- **语料根目录**：`~/Documents/Corpus/`。
- **当前可测试 app**：`dist/FreeRAG.app`。
- **当前版本**：`0.5.0`，构建号 `2`。

产品主线不是“做一个截图工具”，而是：

> 低成本顺滑收集 Mac 上的零散信息，让 LLM 后续能可靠检索、归拢、深挖和复用。

## 当前目录

当前仓库已扁平化为 `FreeRAG/` 项目根，只保留当前产品需要的内容。

```text
FreeRAG/
  README.md
  FreeRAG/
    Info.plist
    Packaging/
      build_native_app.sh
      build_dmg.sh
    README.md
    Resources/Assets/
      freerag.icns
      freerag_icon_source.png
      freerag_status_template.png
    Sources/main.swift
  shared/
    skills/myrag/
      SKILL.md
      scripts/myrag_search.py
  docs/
    README.md
    PRODUCT_PRD.md
    DESIGN_GUIDE.md
    QUALITY_BAR.md
    product_overview.html
    assets/
      freerag_hero.png
      freerag_icon_source.png
    CURRENT_STATE.md
  dist/
    FreeRAG.app
    FreeRAG-0.5.0-build-2.dmg
```

已删除：

- 旧 Windows 实现。
- 旧 PySide6 macOS port。
- 旧 archive/generated。
- 旧图标候选。
- 旧构建缓存和 venv。
- 历史开发日志型文档。
- 重复的 `shared/tools` 脚本副本。

`.DS_Store` 可能被 macOS/Finder 再次生成，它不是产品文件，可随时删除。

## FreeRAG App 现状

实现文件：

```text
FreeRAG/Sources/main.swift
```

当前能力：

- 菜单栏 app，`LSUIElement = true`。
- 浮窗 HUD：
  - 连续收集。
  - 单次截图。
  - 录音。
  - 弱化的语料库入口。
  - 弱化的隐藏按钮。
- 浮窗使用 SF Symbols，按钮有 hover / pressed 状态。
- 浮窗 collection behavior 包含：
  - `canJoinAllSpaces`
  - `fullScreenAuxiliary`
  - `stationary`
  - `ignoresCycle`
- 剪贴板后台收集：
  - 文字 <= 1 MB。
  - 图片 <= 32 MP 且源数据 <= 96 MB。
  - hash 去重。
- 屏幕连续采样：
  - 当前前台窗口优先，失败时屏幕区域。
  - 视觉签名去重。
  - 停止后生成 storyboard。
- 单次截图：
  - 使用同一 screen entry 协议。
- 语音：
  - 16 kHz mono WAV。
  - 保存 `recording.wav`、`transcript.md` 占位、`_meta.json`、`llm_context.md`。
- 设置：
  - 屏幕录制。
  - 辅助功能。
  - 麦克风。
  - 全部准备。
  - 刷新。
  - 登录时自动启动。
  - 重启提示。
- 原材料库：
  - 筛选 screen / clipboard / voice。
  - 搜索 title / summary / llm_context。
  - 识别 MyRAG 写入的 `_myrag_done.json` 已处理标记。
  - 一键清理已处理过的 raw 语料目录，保留 `processed/` 沉淀结果。
  - 打开条目。
  - Finder 显示。

当前 Bundle ID：

```text
com.acegent.freerag
```

旧 Bundle ID 曾出现过：

```text
com.acegent.corpuscollector
com.acegent.corpuscollector.native
```

如果系统设置里还残留旧权限项，可用 `tccutil reset ...` 清理旧 bundle，但不要重置 `com.acegent.freerag`，除非用户明确要求。

## MyRAG Skill 现状

文件：

```text
shared/skills/myrag/SKILL.md
shared/skills/myrag/scripts/myrag_search.py
```

定位：

> MyRAG 不只是检索增量 RAG，而是把有限本地语料按语义归拢、多视角深挖、证据校准，再收束到下一步出口。

默认中文输出。

核心流程：

1. 明确问题。
2. 判断场景。
3. 召回候选语料。
4. 建立材料清单。
5. **主题/项目归拢**：面对乱语料时，先归成 3-8 个候选事项给用户确认。
6. 选择 4-8 个视角。
7. 分视角深读。
8. 证据校准。
9. 反方攻击。
10. 交叉合并。
11. 写回 processed。
12. 回答用户。
13. 收束出口。

三种收束出口：

- 存工作日志。
- 结合已有项目。
- 需要外部调研。

重要设计修正：

- `--suggest-projects` 不能过滤 `FreeRAG` / `LLM` / `RAG` 这类真实领域词。
- 应该过滤的是协议/运营层生成物和字段名，例如 `_meta.json`、`llm_context.md`、`_index.json`、`_library.json`、`README_FOR_LLM.md`、`type/time/files/json/meta` 等。
- 归拢读取用户材料本身：`content.md`、`transcript.md`、`captures.json`、storyboard 文件线索。
- 处理完成后使用 `--mark-processed <entry_id>` 写入 raw 目录的 `_myrag_done.json` 和 `processed/<entry_id>/_myrag_status.json`。
- FreeRAG 的一键清理只删除带 `_myrag_done.json` 的 raw 目录，不删除 `processed/`。

常用命令：

```bash
python3 shared/skills/myrag/scripts/myrag_search.py --recent 10 --format text
python3 shared/skills/myrag/scripts/myrag_search.py --suggest-projects 40 --format text
python3 shared/skills/myrag/scripts/myrag_search.py "<查询>" --format text --deep-plan
python3 shared/skills/myrag/scripts/myrag_search.py --entry "<entry_id>" --format text
python3 shared/skills/myrag/scripts/myrag_search.py --init-processed "<entry_id>"
python3 shared/skills/myrag/scripts/myrag_search.py --mark-processed "<entry_id>" --note "已完成深挖并写回 processed"
```

## 当前语料协议

根目录：

```text
~/Documents/Corpus/
```

结构：

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

推荐 processed：

```text
processed/<entry_id>/
  brief.md
  deep_read.md
  facts.json
  citations.md
  open_questions.md
  ocr.md
  transcript.md
  timeline.md
  tables.csv
  _myrag_status.json
```


MyRAG 多模态处理输出：

- 图片 / 截图：`ocr.md`，必要时 `tables.csv` 或 `tables/*.csv`。
- 屏幕 storyboard：`timeline.md`，必要时抽出界面状态变化和操作链路。
- 语音：`transcript.md`，再抽意图、约束、行动项。
- CSV 用于截图表格、报价表、参数表、排期、对比矩阵等结构化材料。

FreeRAG 不读取这些 processed 内容；它只读取 raw 目录的 `_myrag_done.json` 作为可清理信号。

MyRAG 并发处理协议：主会话负责问题定义、分派、证据校准和最终汇总；子 agent 并发处理图片 OCR/CSV、屏幕 timeline、语音转写、文本深读和噪音识别。子 agent 只提供局部证据和结构化观察，不单独给最终结论，不负责标记 `_myrag_done.json`。

raw 条目完成处理后的清理标记：

```text
screen|clipboard|voice/<entry_id>/_myrag_done.json
```

工作日志默认建议：

```text
processed/_worklogs/
```

## 当前文档状态

保留的文档：

- `docs/PRODUCT_PRD.md`：当前 PRD v2，含实现符合度和下一步。
- `docs/DESIGN_GUIDE.md`：当前设计规范。
- `docs/QUALITY_BAR.md`：验收标准。
- `docs/product_overview.html`：HTML 产品说明。
- `docs/CURRENT_STATE.md`：本文件。

产品说明页：

```text
docs/product_overview.html
```

该 HTML 已做基础 parser 校验。

## 验证结果

最近验证通过：

```bash
FreeRAG/Packaging/build_native_app.sh
codesign --verify --deep --strict --verbose=1 dist/FreeRAG.app
plutil -lint FreeRAG/Info.plist dist/FreeRAG.app/Contents/Info.plist
PYTHONPYCACHEPREFIX=/private/tmp/freerag_pycache python3 -m py_compile shared/skills/myrag/scripts/myrag_search.py
python3 -m html.parser docs/product_overview.html
python3 shared/skills/myrag/scripts/myrag_search.py --recent 1 --format text --deep-plan
python3 shared/skills/myrag/scripts/myrag_search.py --suggest-projects 5 --format text
```

`dist/FreeRAG.app` codesign 结果：

```text
valid on disk
satisfies its Designated Requirement
```

## 仍需实测 / 后续重点

P0：

- 用户真实打开 `dist/FreeRAG.app` 试用。
- 权限状态是否还会出现“已授权但 app 仍说未生效”。
- 连续收集是否会捕获到浮窗自身。
- 单次截图、连续采样、剪贴板图片、语音在真实权限环境下是否全部落盘。
- MyRAG 对真实最近 40 条语料做 `--suggest-projects`，看归拢是否符合用户直觉。
- 一键清理已处理 raw 语料：确认只清理带 `_myrag_done.json` 的 raw 目录，保留 `processed/`。

P1：

- `myrag_search.py` 增加 `--write-worklog`，把确认后的深挖结果保存成 Markdown。
- 原材料库 UI 增加 processed 打开入口。
- 屏幕采样实现真正的稳定退避，而不是固定间隔 + 去重。
- 权限状态区分“未授权”和“已授权但需重启”。

P2：

- 正式 DMG 打包流程固化。
- 正式签名和 notarization。
- 登录项从 LaunchAgent 迁移到更原生的 `SMAppService`。

## 用户偏好和产品标准

用户对质量要求：

- 要像商业化 Mac app，不要像脚本堆。
- 功能可以简单，但不能简陋。
- 界面要干净、精致、well-designed。
- MyRAG 必须中文优先。
- App 和 skill 是一体产品：FreeRAG 收 raw，MyRAG 做 LLM 侧深挖。
- MyRAG 面对乱语料时要先归拢成几件候选事项，让用户确认。
- 不要误伤真实讨论里的 `FreeRAG` / `LLM` / `RAG` 这些词。
- 不要保留补丁痕迹、旧实现、旧生成物、历史垃圾。

## 当前风险备注

- `docs/product_overview.html` 里的 HUD 预览是 HTML 近似，不是 app 截图。
- `dist/FreeRAG.app` 是本地 ad-hoc 签名，不是 notarized release。
- 如果 Finder 再生成 `.DS_Store`，删除即可，不影响产品。
- 当前 app 是单文件 Swift 实现，够小但后续继续长大时应拆模块。
- 权限延续不要靠版本号，而要保持 `CFBundleIdentifier = com.acegent.freerag`、签名身份和安装路径稳定；正式发布前要从 ad-hoc 签名迁移到固定 Developer ID 签名。

## 2026-05-24 存档补充

本次最后状态：用户准备新开对话，要求先把当前状态存档并 git commit。

已完成的新增事项：

- App 设置页底部加入浅灰签名：`八路出品 凑合能用`。
- `docs/product_overview.html` 底部加入同一句浅灰签名；桌面副本 `/Users/acegent/Desktop/product_overview.html` 也已同步。
- `README_FOR_LLM.md` 生成模板补上 MyRAG 多模态推荐输出：`ocr.md`、`transcript.md`、`timeline.md`、`tables.csv`。
- MyRAG 脚本新增 `--image-clusters <N>`：对 `clipboard/image.png` 按 SHA-256 精确折叠重复图，输出代表 entry、尺寸、字节数、标题分布和样本 entry 列表。
- MyRAG skill 文档补充：大量图片语料先分簇，再把每簇代表图分给视觉子 agent，最后由主会话汇总。

真实语料试跑结论：

- `~/Documents/Corpus/_library.json` 共 739 条；666 个唯一 id；73 组重复 id。
- 类型分布：clipboard 732 条，其中 image 727、text 5；screen 4；voice 3。
- 727 张 `clipboard/image.png` 全部存在；按文件内容 SHA-256 精确去重后只有 20 个唯一图片 hash。
- 最大四个精确重复簇分别是 554、101、29、27 张，合计 711 张；剩下 16 张是单图唯一 hash。
- 这不是“相似图聚类”，而是字节级完全相同图片重复写入。
- 高价值 clipboard 代表内容集中在 FreeRAG/Corpus Collector 的权限 onboarding、设置页、录制控制条、Corpus 浏览器、macOS 登录项/后台项证据。
- 低价值噪音主要是状态栏小裁切、单独图标裁切、空白控制条、WatermarkWidget 外部/占位图。
- screen contact sheet 被子 agent 判断为文档/OCR 页面浏览痕迹，适合写成时间线代表事件，不适合逐帧全保留。
- 当前 CLI 环境里 macOS Vision OCR 试跑返回 `nilError`，不能只依赖单一 OCR 后端；MyRAG 需要“视觉子 agent 读代表图 + 可替换 OCR 后端”的策略。

MyRAG 对烂语料的正确处理策略：

1. 先跑 `--image-clusters`，把大量完全重复剪贴板图折叠成少量代表簇。
2. 对每个大簇只保留 1 个代表样本进入视觉/OCR 子 agent。
3. 子 agent 输出 `ocr.md` 草案、`visual_observations.md` 草案、`tables.csv` 草案和 skip/process/optional 决策。
4. 主会话统一汇总、证据校准、写回 `processed/<entry_id>/`。
5. 只有写回完成并确认可复用后，主会话再运行 `--mark-processed` 写 `_myrag_done.json`；FreeRAG 只负责之后的一键 raw 清理。

本次真实语料代表图初步 processed 建议：

- 优先保留：权限 onboarding、完整授权面板、Corpus/clipboard 浏览器、录制中工具条、FreeRAG 设置窗口、macOS 登录项/后台项、重启提示、浅色完整工具条。
- 可选保留：控制条不同灰态/深色态。
- 建议跳过：单图标裁切、状态栏裁切、空白条、WatermarkWidget 文档占位图。

开发工具权限说明：

- 当前项目已迁移到 `/Users/acegent/Documents/GPT Projects/GPT assistant/FreeRAG`。
- 本次会话的工具沙箱可写根仍是旧路径 `/Users/acegent/Documents/GPT Projects/GPT assistant/rag collector`，所以读写新仓库文件会反复要求提权。
- 这不是 FreeRAG app 的 macOS 权限问题，也不是版本号更新导致用户权限重开。
- 下一次新会话如果 cwd/writable root 直接在 FreeRAG 新路径下，开发工具不应继续反复要这个文件写入权限。

下一会话建议第一步：

```bash
cd "/Users/acegent/Documents/GPT Projects/GPT assistant/FreeRAG"
git status --short
python3 shared/skills/myrag/scripts/myrag_search.py --image-clusters 20
```
