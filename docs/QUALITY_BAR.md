# FreeRAG 质量标准

FreeRAG 的功能简单，但交付不能简陋。测试前必须满足以下标准。

## 原生感

- 菜单栏 app，不占 Dock。
- 浮窗可跨普通窗口和全屏空间尽量保持可用。
- 界面图标使用 SF Symbols。
- hover、pressed、active、disabled 状态清楚。
- 权限和设置使用原生窗口。
- 不混用 emoji、位图按钮和不同风格图标。

## 浮窗体验

- Idle 状态只突出连续收集、单次截图、录音。
- 打开语料库和隐藏是弱化二级动作。
- 没有装饰性绿点或无意义状态。
- Active 状态只显示当前任务必需信息。
- 按钮按下后必须有持续到鼠标释放的反馈。

## 采集可靠性

- 剪贴板文字能自动保存。
- 合理大小的剪贴板图片能自动保存。
- 超大剪贴板 payload 被忽略。
- 重复剪贴板内容被抑制。
- 单次截图写入完整条目。
- 连续采样写入截图、storyboard、metadata 和索引。
- 语音写入 WAV、metadata 和转写占位。
- 索引写入有锁和原子替换。

## LLM 友好

每个条目必须有：

- `_meta.json`
- `llm_context.md`
- 原始文件
- `_index.json` / `_library.json` 中的索引记录
- 清晰类型：`screen`、`clipboard`、`voice`
- 可解析相对路径

FreeRAG app 不自动联网、不自动 OCR、不自动转写。MyRAG skill 才负责深挖和处理层写回。

## 权限体验

- 首次启动能引导屏幕录制、辅助功能、麦克风权限。
- 权限缺失时相关动作打开设置，不静默失败。
- 授权后如需重启，设置页明确提示。
- 登录时自动启动只在设置里出现。

## MyRAG

- 默认中文。
- 能检索 `_library.json`，没有则回退 `_index.json`。
- 能读取 raw 和 processed 内容。
- 面对散乱语料时，能先给出 3-8 个主题/项目归拢建议，并让用户确认。
- 能按 L01-L13 多视角深挖。
- 能区分事实、材料主张、意图/愿望和推断。
- 深挖后收束到工作日志、结合项目或外部调研，不无限扩展。

## 当前验收脚本

1. 构建 `dist/FreeRAG.app`。
2. `codesign --verify --deep --strict --verbose=1 dist/FreeRAG.app` 通过。
3. `python3 -m py_compile shared/skills/myrag/scripts/myrag_search.py` 通过。
4. 启动 app 后出现菜单栏图标和浮窗。
5. 复制文字后，`~/Documents/Corpus/clipboard/...` 出现条目。
6. 复制普通图片后，clipboard 图片条目出现。
7. 单次截图生成 screen 条目。
8. 连续收集停止后生成 storyboard。
9. 录音停止后生成 WAV。
10. `myrag_search.py --recent 1 --format text --deep-plan` 输出中文深挖建议。
11. `myrag_search.py --suggest-projects 10 --format text` 输出待归拢语料和归拢格式。
