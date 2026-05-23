"""MyRAG 本地语料检索工具。

默认输出 JSON，方便 LLM 读取；加 --format text 时输出中文可读摘要。
"""

import argparse
import hashlib
import io
import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

CORPUS = Path.home() / "Documents" / "Corpus"
INDEX = CORPUS / "_index.json"
LIBRARY = CORPUS / "_library.json"
PROCESSED = CORPUS / "processed"
RAW_PROCESSED_MARKER = "_myrag_done.json"
PROCESSED_STATUS = "_myrag_status.json"
KIMI = str(Path.home() / ".claude" / "tools" / "kimi.js")

DEEP_LENSES = [
    ("L01 原始事实镜头", "材料明确出现了什么；原话、画面、数值、文件、链接是什么。"),
    ("L02 时间与情境镜头", "这发生在什么时间、什么场景、什么前后文里。"),
    ("L03 人事物关系镜头", "涉及哪些人、项目、产品、地点、账号、文件；彼此是什么关系。"),
    ("L04 意图与需求镜头", "显性需求是什么；隐含动机、真正想解决的问题是什么。"),
    ("L05 结构与机制镜头", "材料内部的层级、流程、因果、约束、规则、依赖是什么。"),
    ("L06 细节与数值镜头", "容易漏掉但重要的细节、参数、版本、价格、数量、字段、阈值是什么。"),
    ("L07 情绪与偏好镜头", "用户在意什么、讨厌什么、审美/口味/工作习惯/判断标准是什么。"),
    ("L08 矛盾与缺口镜头", "哪些地方互相冲突、证据不足、说法含糊、需要补材料。"),
    ("L09 模式与反例镜头", "多条材料中反复出现什么模式；有什么例外或反例。"),
    ("L10 决策与取舍镜头", "已经做了什么选择；为什么放弃其他选项；代价是什么。"),
    ("L11 行动与机会镜头", "接下来能做什么；谁做、怎么做、做到什么算完成。"),
    ("L12 沉淀与复用镜头", "哪些内容值得变成长期记忆、SOP、偏好、模板、检查清单或 prompt 规则。"),
    ("L13 反方攻击镜头", "如果有人不同意这个结论，会攻击哪条证据、哪个假设、哪个遗漏。"),
]

SCENE_LENS_SUGGESTIONS = [
    ("找事实/找出处", "L01、L02、L03、L06、L08、L09"),
    ("复盘一件事", "L02、L04、L05、L08、L10、L11、L13"),
    ("做决策/比较方案", "L04、L05、L06、L08、L10、L11、L13"),
    ("提取用户偏好", "L04、L07、L08、L09、L12"),
    ("整理项目记忆", "L02、L03、L05、L10、L11、L12"),
    ("处理生活/消费/旅行碎片", "L01、L02、L04、L06、L07、L11"),
    ("排错/定位问题", "L01、L02、L05、L06、L08、L11、L13"),
    ("创意/审美/视觉材料", "先用通用镜头，再按需要加画面、风格、版式、信息密度等专项镜头"),
]

CONTEXT_REPLACEMENTS = {
    "Entry ID:": "条目 ID:",
    "Type:": "类型:",
    "Time:": "时间:",
    "Raw Path:": "原材料路径:",
    "Suggested Processed Path:": "建议处理目录:",
    "## Summary": "## 摘要",
    "## Files": "## 文件",
    "## Use With LLM": "## 给 LLM 的使用说明",
    "This entry was collected locally by FreeRAG. Treat these files as source evidence. Prefer exact values from screenshots, clipboard files, audio, or transcripts over assumptions.": "这是 FreeRAG 在本地收集的原材料。请把这些文件当作证据源，优先使用截图、剪贴板、音频或转写里的原始值，不要靠猜。",
    "This is raw evidence collected locally by FreeRAG. Treat the files above as source material, not final knowledge. Prefer exact values from screenshots, clipboard files, audio, or transcripts over assumptions.": "这是 FreeRAG 在本地收集的原材料，不是最终知识。请把上面的文件当作证据源，优先使用截图、剪贴板、音频或转写里的原始值，不要靠猜。",
}

PROTOCOL_SIGNAL_STOPWORDS = {
    "type", "time", "files", "summary", "entry", "path",
    "the", "and", "for", "with", "this", "that",
    "json", "content", "clipboard", "image", "voice", "screen", "meta",
    "使用说明", "摘要", "文件", "类型", "时间", "原材料", "剪贴板文字",
}


def read_text(path: Path, limit: int = 12000) -> str:
    try:
        text = path.read_text(encoding="utf-8")
    except (FileNotFoundError, UnicodeDecodeError, OSError):
        return ""
    return text[:limit]


def normalize_context(text: str) -> str:
    for old, new in CONTEXT_REPLACEMENTS.items():
        text = text.replace(old, new)
    return text


def load_index() -> tuple[list[dict], str]:
    source = LIBRARY if LIBRARY.exists() else INDEX
    if not source.exists():
        return [], ""
    try:
        data = json.loads(source.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return [], str(source)
    return data.get("entries", []), str(source)


def entry_dir(entry: dict) -> Path:
    return CORPUS / str(entry.get("path", ""))


def processed_dir(entry_id: str) -> Path:
    return PROCESSED / entry_id


def raw_processed_marker(entry: dict) -> Path:
    return entry_dir(entry) / RAW_PROCESSED_MARKER


def processed_status_path(entry_id: str) -> Path:
    return processed_dir(entry_id) / PROCESSED_STATUS


def is_marked_processed(entry: dict) -> bool:
    entry_id = str(entry.get("id", ""))
    if not entry_id:
        return False
    return raw_processed_marker(entry).exists() or processed_status_path(entry_id).exists()


def read_processed(entry_id: str) -> str:
    if not entry_id:
        return ""
    root = processed_dir(entry_id)
    if not root.exists():
        return ""
    parts = []
    for name in ("brief.md", "deep_read.md", "facts.json", "citations.md", "open_questions.md", "ocr.md", "transcript.md", "timeline.md", "tables.csv"):
        path = root / name
        text = read_text(path, 16000)
        if text:
            parts.append(f"\n[processed/{entry_id}/{name}]\n{text}")
    return "\n".join(parts)


def read_raw_context(entry: dict, include_ocr: bool = False) -> str:
    root = entry_dir(entry)
    entry_type = entry.get("type", "")
    parts = []

    context = read_text(root / "llm_context.md", 12000)
    if context:
        parts.append(normalize_context(context))

    if entry_type == "clipboard":
        content = read_text(root / "content.md", 12000)
        if content:
            parts.append(content)
    elif entry_type == "voice":
        transcript = read_text(root / "transcript.md", 12000)
        if transcript:
            parts.append(transcript)
    elif entry_type == "screen":
        stitched_dir = root / "stitched"
        if stitched_dir.exists():
            for png in sorted(stitched_dir.glob("*.png"))[:6]:
                parts.append(f"[storyboard 图片] {png.name}")
                if include_ocr:
                    ocr_text = ocr(str(png))
                    if ocr_text:
                        parts.append(ocr_text)
        else:
            for png in sorted(root.glob("*.png"))[:12]:
                parts.append(f"[截图] {png.name}")

    return "\n".join(parts)


def score_entry(entry: dict, terms: list[str], content: str) -> int:
    fields = [
        str(entry.get("id", "")),
        str(entry.get("type", "")),
        str(entry.get("subtype", "")),
        str(entry.get("title", "")),
        str(entry.get("summary", "")),
        content,
    ]
    haystack = " ".join(fields).lower()
    if not terms:
        return 1
    score = 0
    for term in terms:
        if term in haystack:
            score += 1
        if term and term in str(entry.get("title", "")).lower():
            score += 2
        if term and term in str(entry.get("summary", "")).lower():
            score += 2
    if read_processed(str(entry.get("id", ""))):
        score += 2
    return score


def build_result(entry: dict, score: int, content: str) -> dict:
    entry_id = str(entry.get("id", ""))
    processed_path = str(entry.get("processed_path") or f"processed/{entry_id}/")
    return {
        "id": entry_id,
        "type": entry.get("type", ""),
        "subtype": entry.get("subtype", ""),
        "time": entry.get("time", ""),
        "title": entry.get("title", ""),
        "score": score,
        "summary": str(entry.get("summary", ""))[:300],
        "path": entry.get("path", ""),
        "processed_path": processed_path,
        "has_processed": processed_dir(entry_id).exists(),
        "is_marked_processed": is_marked_processed(entry),
        "content": content[:16000],
    }


def search(query: str, limit: int, include_ocr: bool) -> list[dict]:
    entries, _ = load_index()
    terms = query.lower().split()
    results = []
    for entry in entries:
        entry_id = str(entry.get("id", ""))
        processed = read_processed(entry_id)
        raw = read_raw_context(entry, include_ocr=include_ocr)
        content = (processed + "\n" + raw).strip()
        score = score_entry(entry, terms, content)
        if terms and score == 0:
            continue
        results.append(build_result(entry, score, content))
    results.sort(key=lambda r: (int(r["score"]), str(r["time"])), reverse=True)
    return results[:limit]


def get_entry(entry_id: str, include_ocr: bool) -> list[dict]:
    entries, _ = load_index()
    for entry in entries:
        if str(entry.get("id", "")) == entry_id:
            processed = read_processed(entry_id)
            raw = read_raw_context(entry, include_ocr=include_ocr)
            return [build_result(entry, 999, (processed + "\n" + raw).strip())]
    return []


def recent(limit: int) -> list[dict]:
    entries, _ = load_index()
    output = []
    for entry in entries[:limit]:
        entry_id = str(entry.get("id", ""))
        content = read_processed(entry_id) or read_raw_context(entry, include_ocr=False)
        output.append(build_result(entry, 1, content))
    return output


def suggest_projects(limit: int) -> list[dict]:
    entries, _ = load_index()
    output = []
    for entry in entries[:limit]:
        entry_id = str(entry.get("id", ""))
        content = read_project_material(entry)
        output.append({
            "id": entry_id,
            "type": entry.get("type", ""),
            "subtype": entry.get("subtype", ""),
            "time": entry.get("time", ""),
            "title": entry.get("title", ""),
            "summary": str(entry.get("summary", ""))[:240],
            "path": entry.get("path", ""),
            "processed_path": entry.get("processed_path", f"processed/{entry_id}/"),
            "is_marked_processed": is_marked_processed(entry),
            "signals": extract_signals(content, entry),
            "preview": compact_preview(content),
        })
    return output



def image_hash(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def image_dimensions(path: Path) -> str:
    data = path.read_bytes()[:32]
    if data.startswith(b"\x89PNG\r\n\x1a\n") and len(data) >= 24:
        width = int.from_bytes(data[16:20], "big")
        height = int.from_bytes(data[20:24], "big")
        return f"{width}x{height}"
    return ""


def image_clusters(limit: int = 40) -> list[dict]:
    entries, _ = load_index()
    clusters: dict[str, dict] = {}
    for entry in entries:
        if entry.get("type") != "clipboard" or entry.get("subtype") != "image":
            continue
        path = entry_dir(entry) / "image.png"
        if not path.exists():
            continue
        try:
            digest = image_hash(path)
            size = image_dimensions(path)
            bytes_len = path.stat().st_size
        except OSError:
            continue
        cluster = clusters.setdefault(digest, {
            "sha256": digest,
            "count": 0,
            "sample_entry": str(entry.get("id", "")),
            "sample_path": str(path.relative_to(CORPUS)),
            "sample_title": str(entry.get("title", "")),
            "dimensions": size,
            "bytes": bytes_len,
            "titles": {},
            "entries": [],
        })
        cluster["count"] += 1
        title = str(entry.get("title", ""))
        cluster["titles"][title] = cluster["titles"].get(title, 0) + 1
        if len(cluster["entries"]) < 12:
            cluster["entries"].append(str(entry.get("id", "")))
    output = []
    for cluster in clusters.values():
        titles = sorted(cluster["titles"].items(), key=lambda kv: (-kv[1], kv[0]))
        cluster["titles"] = [{"title": k, "count": v} for k, v in titles[:8]]
        output.append(cluster)
    output.sort(key=lambda item: (-int(item["count"]), str(item["sample_entry"])))
    return output[:limit]

def read_project_material(entry: dict) -> str:
    root = entry_dir(entry)
    entry_type = entry.get("type", "")
    parts = [
        str(entry.get("title", "")),
        str(entry.get("summary", "")),
    ]
    if entry_type == "clipboard":
        content = read_text(root / "content.md", 4000)
        if content:
            parts.append(content)
    elif entry_type == "voice":
        transcript = read_text(root / "transcript.md", 4000)
        if transcript:
            parts.append(transcript)
    elif entry_type == "screen":
        captures = read_text(root / "captures.json", 3000)
        if captures:
            parts.append(captures)
        stitched_dir = root / "stitched"
        if stitched_dir.exists():
            parts.extend([f"storyboard: {p.name}" for p in sorted(stitched_dir.glob("*.png"))[:6]])
    return "\n".join(p for p in parts if p).strip()


def compact_preview(text: str, limit: int = 700) -> str:
    text = " ".join(text.split())
    return text[:limit]


def extract_signals(text: str, entry: dict) -> list[str]:
    haystack = " ".join([
        str(entry.get("title", "")),
        str(entry.get("summary", "")),
        text[:2000],
    ])
    candidates: list[str] = []
    current = ""
    for ch in haystack:
        if "\u4e00" <= ch <= "\u9fff":
            current += ch
        else:
            if 2 <= len(current) <= 10:
                candidates.append(current)
            current = ""
    if 2 <= len(current) <= 10:
        candidates.append(current)

    words = []
    token = ""
    for ch in haystack.lower():
        if ch.isascii() and (ch.isalnum() or ch in "-_"):
            token += ch
        else:
            if len(token) >= 3:
                words.append(token)
            token = ""
    if len(token) >= 3:
        words.append(token)

    counts: dict[str, int] = {}
    for item in candidates + words:
        if item in PROTOCOL_SIGNAL_STOPWORDS or item.isdigit() or "2026" in item or len(item) > 24:
            continue
        if "_" in item and any(ch.isdigit() for ch in item):
            continue
        counts[item] = counts.get(item, 0) + 1
    ranked = sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))
    return [k for k, _ in ranked[:8]]


def init_processed(entry_id: str) -> dict:
    entries, _ = load_index()
    entry = next((e for e in entries if str(e.get("id", "")) == entry_id), None)
    if not entry:
        return {"错误": f"没有找到条目: {entry_id}"}
    root = processed_dir(entry_id)
    root.mkdir(parents=True, exist_ok=True)
    title = entry.get("title") or entry.get("summary") or entry_id
    templates = {
        "brief.md": f"# {title}\n\n## 关键结论\n\n## 可引用事实\n\n## 我的整理/推断\n\n## 置信度与缺口\n\n",
        "deep_read.md": "# 多视角深读\n\n## 问题与场景判断\n\n## L01 原始事实镜头\n\n## L02 时间与情境镜头\n\n## L03 人事物关系镜头\n\n## L04 意图与需求镜头\n\n## L05 结构与机制镜头\n\n## L06 细节与数值镜头\n\n## L07 情绪与偏好镜头\n\n## L08 矛盾与缺口镜头\n\n## L09 模式与反例镜头\n\n## L10 决策与取舍镜头\n\n## L11 行动与机会镜头\n\n## L12 沉淀与复用镜头\n\n## L13 反方攻击镜头\n\n## 交叉合并\n\n",
        "facts.json": json.dumps({
            "条目id": entry_id,
            "主题": str(title),
            "实体": [],
            "事实": [],
            "数值": [],
            "表格": [],
            "图片观察": [],
            "音频转写": [],
            "时间线": [],
            "行动项": [],
            "风险": [],
            "证据等级": [],
            "反方攻击点": [],
            "待深挖": [],
            "置信度": "medium"
        }, ensure_ascii=False, indent=2) + "\n",
        "citations.md": "# 证据来源\n\n",
        "open_questions.md": "# 待确认问题\n\n",
        "ocr.md": "# 图片 / 截图 OCR 与视觉观察\n\n## 可读文字\n\n## 界面状态与画面观察\n\n## 表格线索\n\n",
        "transcript.md": "# 音频转写\n\n## 原始转写\n\n## 说话意图与行动项\n\n",
        "timeline.md": "# 屏幕 / 多帧时间线\n\n",
        "tables.csv": "source,table_name,row_index,column,value,confidence,note\n",
    }
    written = []
    skipped = []
    for name, body in templates.items():
        path = root / name
        if path.exists():
            skipped.append(name)
        else:
            path.write_text(body, encoding="utf-8")
            written.append(name)
    return {"条目id": entry_id, "目录": str(root), "已创建": written, "已存在": skipped}


def mark_processed(entry_id: str, note: str = "") -> dict:
    entries, _ = load_index()
    entry = next((e for e in entries if str(e.get("id", "")) == entry_id), None)
    if not entry:
        return {"错误": f"没有找到条目: {entry_id}"}

    raw_root = entry_dir(entry)
    processed_root = processed_dir(entry_id)
    processed_root.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema": "myrag.raw_processed_marker.v1",
        "entry_id": entry_id,
        "status": "processed",
        "marked_at": datetime.now().isoformat(timespec="seconds"),
        "raw_path": str(raw_root),
        "processed_path": str(processed_root),
        "marker_for": "FreeRAG 一键清理已处理过语料",
        "status_file_for": "MyRAG 自己记录处理状态，FreeRAG 不读取 processed 状态",
        "note": note,
    }
    written = []
    if raw_root.exists():
        raw_marker = raw_root / RAW_PROCESSED_MARKER
        raw_marker.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        written.append(str(raw_marker))
    status = processed_root / PROCESSED_STATUS
    status.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    written.append(str(status))
    return {"条目id": entry_id, "状态": "已标记处理完成", "写入": written}


def ocr(img_path: str) -> str:
    prompt = "提取图片里所有可读文字、表格和结构化数据。中文输出；数值原样；多表格用[表格:名称]标记；不确定处标注[不确定]。"
    try:
        kwargs = {}
        if sys.platform.startswith("win") and hasattr(subprocess, "CREATE_NO_WINDOW"):
            kwargs["creationflags"] = subprocess.CREATE_NO_WINDOW
        result = subprocess.run(
            ["node", KIMI, "--image", img_path, "--prompt", prompt],
            capture_output=True,
            encoding="utf-8",
            timeout=180,
            **kwargs,
        )
        out = (result.stdout or "").strip()
        return out if result.returncode == 0 else ""
    except Exception as exc:
        return f"OCR 失败: {exc}"


def add_deep_plan(payload: dict) -> dict:
    payload["深挖建议"] = [
        {"镜头": name, "读法": guide}
        for name, guide in DEEP_LENSES
    ]
    payload["场景选镜建议"] = [
        {"场景": scene, "优先镜头": lenses}
        for scene, lenses in SCENE_LENS_SUGGESTIONS
    ]
    payload["处理建议"] = {
        "写回目录": "processed/<entry_id>/",
        "推荐文件": ["brief.md", "deep_read.md", "facts.json", "citations.md", "open_questions.md", "ocr.md", "transcript.md", "timeline.md", "tables.csv"],
        "原则": "先判断场景，再选择少数镜头逐轮读材料，最后做证据校准和反方攻击；不要一遍看完就泛泛总结。"
    }
    payload["证据校准"] = {
        "可验证事实": "材料明确出现，能指向原文、截图帧、录音转写、文件或数值。",
        "材料主张": "材料里有人这么说，但还缺外部验证或反例检查。",
        "意图愿望": "想做、计划做、希望做到，不等于已经做到。",
        "我的推断": "基于材料合理推出，但不是材料直接给出的事实。"
    }
    payload["收束出口"] = [
        {
            "出口": "存工作日志",
            "适用": "本次深挖本身已经形成有价值的过程记录、结论、偏好、决策或待办。",
            "动作": "询问用户是否保存；同意后生成中文 Markdown，默认放入 ~/Documents/Corpus/processed/_worklogs/。"
        },
        {
            "出口": "结合已有项目",
            "适用": "深挖结果应该进入某个项目、产品、客户、研究主题或个人长期事项。",
            "动作": "先问用户要结合哪个项目和项目资料路径；不要猜。"
        },
        {
            "出口": "需要外部调研",
            "适用": "本地 RAG 缺最新事实、市场信息、竞品状态、政策、价格、版本或第三方证据。",
            "动作": "说明本地 RAG 已挖到哪里和外部缺口；调研后把外部事实与本地 RAG 分开标注。"
        }
    ]
    payload["归拢提醒"] = "如果语料很散，先把条目归成 3-8 个候选事项给用户确认，再进入工作日志、项目结合或外部调研。"
    payload["并发处理建议"] = {
        "模式": "主会话分派，子 agent 并发读材料，主会话统一汇总。",
        "适用": "20 条以上、多模态混合、图片/音频/屏幕可独立处理时默认采用。",
        "可分派任务": ["图片 OCR 与表格抽取", "屏幕 storyboard 时间线", "语音转写与行动项", "文本条目主题深读", "低价值噪音和重复项识别"],
        "子 agent 输出": ["范围", "关键观察", "结构化产物", "证据引用", "是否建议标记 _myrag_done.json"],
        "汇总原则": "最终结论、证据校准、反方攻击、写回 processed 和 --mark-processed 由主会话负责。"
    }
    return payload


def add_project_suggestion_plan(payload: dict) -> dict:
    payload["归拢输出要求"] = {
        "目的": "让 LLM 按语义把乱语料归成几件候选事项，先给用户确认。",
        "候选事项字段": ["名称", "一句话说明", "代表条目", "归在一起的证据", "置信度", "建议出口"],
        "注意": "脚本只提供候选条目和信号词；最终分组要由 LLM 结合语义判断，不要机械按关键词聚类。"
    }
    return payload


def print_text(results: list[dict], deep_plan: bool) -> None:
    if not results:
        print("没有命中语料。可以换关键词、查看 --recent，或先用 FreeRAG 收集相关材料。")
        return
    for idx, item in enumerate(results, 1):
        title = item.get("title") or item.get("summary") or item.get("id")
        print(f"## {idx}. {title}")
        print(f"- 条目: {item.get('id')}")
        print(f"- 类型: {item.get('type')} / {item.get('subtype')}")
        print(f"- 时间: {item.get('time')}")
        print(f"- 原材料路径: ~/Documents/Corpus/{item.get('path')}")
        print(f"- 处理目录: ~/Documents/Corpus/{item.get('processed_path')}")
        print(f"- 已处理: {'是' if item.get('has_processed') else '否'}")
        print(f"- 清理标记: {'已标记' if item.get('is_marked_processed') else '未标记'}")
        summary = item.get("summary") or ""
        if summary:
            print(f"- 摘要: {summary}")
        content = (item.get("content") or "").strip()
        if content:
            preview = content[:1200].replace("\n\n\n", "\n\n")
            print("\n```text")
            print(preview)
            print("```")
        print()
    if deep_plan:
        print("## 通用深挖镜头")
        for name, guide in DEEP_LENSES:
            print(f"- {name}: {guide}")
        print("\n## 场景选镜建议")
        for scene, lenses in SCENE_LENS_SUGGESTIONS:
            print(f"- {scene}: {lenses}")
        print("\n## 收束出口")
        print("- 存工作日志: 本次深挖已经有独立价值时，询问用户是否生成 Markdown。")
        print("- 结合已有项目: 需要进入某个项目时，先问项目名称和资料路径，不要猜。")
        print("- 需要外部调研: 本地 RAG 缺外部事实或第三方证据时，说明缺口后再调研。")


def print_project_suggestions(items: list[dict]) -> None:
    if not items:
        print("没有可归拢的语料。")
        return
    print("# 待归拢语料")
    print()
    print("下面不是最终分组，而是给 LLM 做语义归拢的候选材料。请把它们收束成 3-8 个候选事项，给用户确认。")
    print()
    for idx, item in enumerate(items, 1):
        title = item.get("title") or item.get("summary") or item.get("id")
        print(f"## {idx}. {title}")
        print(f"- 条目: {item.get('id')}")
        print(f"- 类型: {item.get('type')} / {item.get('subtype')}")
        print(f"- 时间: {item.get('time')}")
        print(f"- 路径: ~/Documents/Corpus/{item.get('path')}")
        print(f"- 清理标记: {'已标记' if item.get('is_marked_processed') else '未标记'}")
        signals = item.get("signals") or []
        if signals:
            print(f"- 信号词: {'、'.join(signals)}")
        preview = item.get("preview") or ""
        if preview:
            print(f"- 预览: {preview}")
        print()
    print("## 归拢结果格式")
    print("- 名称: 短中文名")
    print("- 一句话说明: 这坨语料大概在说什么")
    print("- 代表条目: 3-6 个 entry id 或路径")
    print("- 归在一起的证据: 为什么它们属于同一件事")
    print("- 置信度: high / medium / low")
    print("- 建议出口: 存工作日志 / 结合已有项目 / 外部调研 / 暂不处理")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="MyRAG 本地语料检索与处理辅助工具")
    parser.add_argument("query", nargs="*", help="查询关键词或自然语言问题")
    parser.add_argument("--entry", help="按 entry id 精确读取")
    parser.add_argument("--recent", type=int, help="读取最近 N 条")
    parser.add_argument("--suggest-projects", type=int, help="读取最近 N 条，供 LLM 归拢成候选项目/主题")
    parser.add_argument("--image-clusters", type=int, help="按精确 SHA-256 折叠 clipboard image，输出重复簇代表样本")
    parser.add_argument("--limit", type=int, default=5, help="最多返回条数")
    parser.add_argument("--format", choices=["json", "text"], default="json", help="输出格式")
    parser.add_argument("--ocr", action="store_true", help="对 screen storyboard 尝试 OCR")
    parser.add_argument("--deep-plan", action="store_true", help="附带多视角深挖建议")
    parser.add_argument("--init-processed", help="为指定 entry id 创建中文 processed 模板")
    parser.add_argument("--mark-processed", help="把指定 entry id 标记为已处理，供 FreeRAG 一键清理原材料")
    parser.add_argument("--note", default="", help="配合 --mark-processed 记录处理说明")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.init_processed:
        payload = init_processed(args.init_processed)
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return 0

    if args.mark_processed:
        payload = mark_processed(args.mark_processed, args.note)
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return 0

    entries, source = load_index()
    if not entries:
        payload = {"错误": "没有找到语料索引", "语料目录": str(CORPUS)}
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return 1

    if args.image_clusters:
        results = image_clusters(args.image_clusters)
    elif args.entry:
        results = get_entry(args.entry, include_ocr=args.ocr)
    elif args.suggest_projects:
        results = suggest_projects(args.suggest_projects)
    elif args.recent:
        results = recent(args.recent)
    else:
        query = " ".join(args.query).strip()
        if not query:
            print("用法: python myrag_search.py <查询关键词>，或使用 --recent / --entry。")
            return 1
        results = search(query, limit=args.limit, include_ocr=args.ocr)

    if args.format == "text":
        if args.suggest_projects:
            print_project_suggestions(results)
        else:
            print_text(results, args.deep_plan)
        return 0

    payload: dict | list[dict]
    payload = {
        "语料索引": source,
        "结果数": len(results),
        "results": results,
    }
    if args.image_clusters:
        payload["说明"] = "clipboard image 已按文件内容 SHA-256 精确折叠；count 表示完全相同图片出现次数，不是相似图聚类。"
    if args.suggest_projects:
        payload = add_project_suggestion_plan(payload)
    if args.deep_plan:
        payload = add_deep_plan(payload)
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
