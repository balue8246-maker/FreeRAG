# MyRAG 安装与模型适配

这份文档只处理“当前模型/机器怎样具备 MyRAG 所需能力”。日常语料处理规则在 `SKILL.md`。安装适配完成后，运行时应回到通用 skill，不要把本机路径、临时 workaround 或某个模型的限制混入日常回答。

## 目标能力

MyRAG 至少需要文本读取能力。要完整处理 FreeRAG 语料，还需要：

- Vision：读取 `clipboard/image.png`、screen 截图和 storyboard。
- ASR：把 `voice/<entry>/recording.wav` 转成 `transcript.md`。
- 可选 diarization：把转写片段标注为不同说话人。

缺哪项就明确降级。不要假装读过图片或音频。

## 模型能力矩阵

| 当前环境 | 文本 | 图片/截图 | 音频 | 建议 |
| --- | --- | --- | --- | --- |
| Claude Code + Claude Sonnet/Opus | yes | 通常可直接读 | no | 图片直接读；音频配置 Whisper 或要求已有 transcript。 |
| Claude Code + DeepSeek | yes | no | no | 配置外部 Vision 后端；音频配置 Whisper。 |
| Codex / GPT 多模态环境 | yes | depends | no | 有视觉就直接读；无视觉就配置外部 Vision 后端。 |
| 纯本地文本模型 | yes | no | no | 只能处理文本和已有 transcript；图片/音频必须外接工具。 |

运行前先判断当前模型是否真的能直接看图。不能看图时，所有图片和截图都必须走 Vision 后端。

## Vision 后端

优先使用通用环境变量，不要把个人机器路径写进 `SKILL.md`。

推荐接口：

```bash
export MYRAG_VISION_COMMAND='python3 ~/.claude/tools/kimi.py --image {image} --prompt {prompt}'
```

兼容旧接口：

```bash
export MYRAG_OCR_COMMAND='python3 ~/.claude/tools/kimi.py --image {image} --prompt {prompt}'
```

约定：

- `{image}` 会替换成图片路径。
- `{prompt}` 会替换成识图提示词。
- 后端可以是 Kimi、GPT、Claude、多模态本地模型或任何能从命令行返回文字描述的工具。
- 没有 Vision 后端时，MyRAG 仍可完成索引、去重和代表图定位，但必须声明“未配置 Vision 后端，无法确认图片内容”。

验证：

```bash
python3 scripts/myrag_search.py --image-clusters 20
```

再找一个代表图片，请当前模型或 Vision 命令描述图片内容。验证通过后再处理真实任务。

## ASR 后端

默认推荐 `openai-whisper` 本地转写：

```bash
pip3 install openai-whisper
brew install ffmpeg
```

常用模型：

| 模型 | 速度 | 中文质量 | 适用场景 |
| --- | --- | --- | --- |
| `tiny` | 极快 | 差 | 快速判断有没有人说话。 |
| `base` | 快 | 一般 | 短音频。 |
| `small` | 中 | 尚可 | 中等音频。 |
| `turbo` | 中 | 好 | 默认推荐，长中文录音优先。 |

如果 `ffmpeg` 不可用，但录音是 FreeRAG 保存的 WAV，可以用 Python `wave` 直接读音频数组再交给 Whisper。这个是故障绕过方案，不是默认路径：

```python
import wave
import numpy as np
import whisper

with wave.open(wav_path, "rb") as wf:
    audio = np.frombuffer(wf.readframes(wf.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0
    if wf.getnchannels() > 1:
        audio = audio.reshape(-1, wf.getnchannels()).mean(axis=1)

model = whisper.load_model("turbo")
result = model.transcribe(audio, language="zh", fp16=False)

with open("transcript.md", "w", encoding="utf-8") as f:
    for seg in result["segments"]:
        f.write(f"[{seg['start']:.1f}s - {seg['end']:.1f}s] {seg['text'].strip()}\n")
```

转写输出应写回 raw voice 条目目录：

```text
voice/<entry_id>/transcript.md
```

转写全文是证据，不等于最终交付。最终给用户的是按主题组织的摘要、行动项、判断、风险和证据时间点。

## 说话人分离

只有在用户需要“谁说了什么”时才配置 diarization。否则先做纯转写和内容摘要。

常见方案：

```bash
pip3 install whisperx
```

通常还需要：

- HuggingFace token。
- 同意对应 pyannote 模型协议。
- 可访问 HuggingFace 或镜像。

输出建议：

```text
voice/<entry_id>/transcript_labeled.md
```

如果无法完成说话人分离，不要阻塞内容摘要；用“说话人未区分”标注。

## 给模型的安装适配提示

当用户要求“装好 MyRAG”或“让这个模型能处理 FreeRAG 语料”时，按以下顺序做：

1. 判断当前模型是否能直接读图片。
2. 判断当前环境是否能转写 WAV。
3. 检查 `scripts/myrag_search.py` 可运行。
4. 配置 Vision 后端，或明确当前只能处理文本和已有 transcript。
5. 配置 ASR 后端，或明确当前无法处理未转写录音。
6. 用一张图片、一个最近条目、一个录音样本做验证。
7. 验证完成后再进入正式语料处理。

不要在安装阶段写 `_myrag_done.json`，不要清理 raw，除非用户明确要求并已经确认内容已接盘。

## 验证命令

```bash
python3 scripts/myrag_search.py --recent 5 --format text
python3 scripts/myrag_search.py --suggest-projects 20 --format text
python3 scripts/myrag_search.py --image-clusters 20
```

如果这些命令能跑，说明索引和检索基础可用。Vision 和 ASR 仍需分别用真实图片和录音验证。
