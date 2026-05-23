import AppKit
import AVFoundation
import ApplicationServices
import CoreGraphics
import CryptoKit
import Foundation

let corpusRoot = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Documents")
    .appendingPathComponent("Corpus")
let screenRoot = corpusRoot.appendingPathComponent("screen")
let voiceRoot = corpusRoot.appendingPathComponent("voice")
let clipRoot = corpusRoot.appendingPathComponent("clipboard")
let processedRoot = corpusRoot.appendingPathComponent("processed")
let indexURL = corpusRoot.appendingPathComponent("_index.json")
let libraryURL = corpusRoot.appendingPathComponent("_library.json")
let rawProcessedMarkerName = "_myrag_done.json"
let launchAgentURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library")
    .appendingPathComponent("LaunchAgents")
    .appendingPathComponent("com.acegent.freerag.plist")

func nowISO() -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
    return f.string(from: Date())
}

func timestamp(_ format: String = "yyyyMMdd_HHmmss") -> String {
    let f = DateFormatter()
    f.dateFormat = format
    return f.string(from: Date())
}

func uniqueID(_ suffix: String? = nil) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyyMMdd_HHmmss_SSS"
    let base = f.string(from: Date())
    let tail = UUID().uuidString.prefix(6).lowercased()
    if let suffix {
        return "\(base)_\(tail)_\(suffix)"
    }
    return "\(base)_\(tail)"
}

func sanitize(_ raw: String) -> String {
    let allowed = CharacterSet.alphanumerics
        .union(CharacterSet(charactersIn: " _-()（）"))
    let s = raw.unicodeScalars.filter { allowed.contains($0) || ("\u{4e00}" <= String($0) && String($0) <= "\u{9fff}") }
    let str = String(String.UnicodeScalarView(s)).trimmingCharacters(in: .whitespacesAndNewlines)
    return String((str.isEmpty ? "screen" : str).prefix(36))
}

func ensureDir(_ url: URL) {
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

func sha256Hex(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func writeJSON(_ obj: Any, to url: URL) {
    if let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]) {
        try? data.write(to: url)
    }
}

func normalizedLibraryEntries(_ entries: [[String: Any]]) -> [[String: Any]] {
    entries.map { entry -> [String: Any] in
        let relativePath = entry["path"] as? String ?? ""
        let entryID = entry["id"] as? String ?? ""
        return [
            "id": entryID,
            "type": entry["type"] as? String ?? "",
            "subtype": entry["subtype"] as? String ?? "",
            "time": entry["time"] as? String ?? "",
            "title": entry["title"] as? String ?? "",
            "summary": entry["summary"] as? String ?? "",
            "path": relativePath,
            "llm_context": relativePath.isEmpty ? "" : "\(relativePath)llm_context.md",
            "processed_path": "processed/\(entryID)/",
            "role": "raw",
            "tags": entry["tags"] as? [String] ?? []
        ]
    }
}

func writeCorpusIndexAndLibrary(_ entries: [[String: Any]]) {
    writeJSON([
        "updated": nowISO(),
        "entries": entries
    ], to: indexURL)
    writeJSON([
        "schema": "freerag.library.v1",
        "updated": nowISO(),
        "root": corpusRoot.path,
        "raw_roots": ["screen/", "clipboard/", "voice/"],
        "processed_root": "processed/",
        "processed_marker": rawProcessedMarkerName,
        "entries": normalizedLibraryEntries(entries)
    ], to: libraryURL)
}

func rawEntryURL(for entry: [String: Any]) -> URL? {
    guard let path = entry["path"] as? String, !path.isEmpty else { return nil }
    return corpusRoot.appendingPathComponent(path)
}

func entryHasRawProcessedMarker(_ entry: [String: Any]) -> Bool {
    if let rawURL = rawEntryURL(for: entry),
       FileManager.default.fileExists(atPath: rawURL.appendingPathComponent(rawProcessedMarkerName).path) {
        return true
    }
    return false
}

func entryIsMarkedProcessed(_ entry: [String: Any]) -> Bool {
    entryHasRawProcessedMarker(entry)
}

func writeLLMContext(title: String, type: String, summary: String, files: [String], to dir: URL) {
    let fileList = files.map { "- `\($0)`" }.joined(separator: "\n")
    let entryID = dir.lastPathComponent
    let processedPath = "processed/\(entryID)/"
    let body = """
    # \(title)

    条目 ID: \(entryID)
    类型: \(type)
    时间: \(nowISO())
    原材料路径: \(dir.path)
    建议处理目录: \(processedPath)

    ## 摘要
    \(summary)

    ## 文件
    \(fileList.isEmpty ? "- 无" : fileList)

    ## 给 LLM 的使用说明

    这是 FreeRAG 在本地收集的原材料，不是最终知识。请把上面的文件当作证据源，优先使用截图、剪贴板、音频或转写里的原始值，不要靠猜。

    处理这个条目时，建议先判断问题场景，再用多个视角逐轮阅读，例如事实、时间、关系、意图、结构、细节、偏好、矛盾、模式、行动和可复用规则。

    如果整理出可复用结果，请写入 `~/Documents/Corpus/\(processedPath)`，推荐文件：
    - `brief.md`：中文摘要、关键结论、可引用事实
    - `deep_read.md`：多视角深读记录
    - `facts.json`：结构化事实、实体、数值、时间线、行动项
    - `citations.md`：原材料引用，写清文件名、截图帧、时间戳
    - `open_questions.md`：材料不足、矛盾或需要人工确认的问题
    """
    try? body.write(to: dir.appendingPathComponent("llm_context.md"), atomically: true, encoding: .utf8)
}

final class CorpusStore {
    private let lock = NSLock()

    func addEntry(_ entry: [String: Any]) {
        lock.lock()
        defer { lock.unlock() }
        ensureDir(corpusRoot)
        ensureDir(processedRoot)
        writeCorpusReadme()
        var index: [String: Any] = ["updated": "", "entries": []]
        if let data = try? Data(contentsOf: indexURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            index = json
        }
        var entries = index["entries"] as? [[String: Any]] ?? []
        entries.insert(entry, at: 0)
        writeCorpusIndexAndLibrary(entries)
    }

    private func writeCorpusReadme() {
        let readme = corpusRoot.appendingPathComponent("README_FOR_LLM.md")
        if FileManager.default.fileExists(atPath: readme.path) {
            let existing = (try? String(contentsOf: readme, encoding: .utf8)) ?? ""
            guard !existing.contains("MyRAG skill") else { return }
        }
        let body = """
        # FreeRAG Corpus

        这个目录是给 LLM 使用的本地原材料语料池。

        ## 原材料
        - `screen/`：屏幕截图和连续采样 storyboard
        - `clipboard/`：剪贴板文字和图片
        - `voice/`：本地录音和转写占位

        每个原材料条目通常包含：
        - `_meta.json`
        - `llm_context.md`
        - 图片、音频、Markdown 等原始文件

        ## 处理结果
        LLM 工具应该把可复用的抽取、整理、转写、OCR、综合结果写入：

        `processed/<entry_id>/`

        推荐文件：
        - `brief.md`
        - `deep_read.md`
        - `ocr.md`
        - `transcript.md`
        - `timeline.md`
        - `tables.csv`
        - `facts.json`
        - `citations.md`
        - `open_questions.md`

        ## 已处理标记
        MyRAG 确认某条原材料已经沉淀到 `processed/<entry_id>/` 后，应给原材料目录写入：

        `screen|clipboard|voice/<entry_id>/_myrag_done.json`

        FreeRAG 原材料库里的“一键清理已处理过语料”只会清理带这个标记的原材料目录，不会删除 `processed/` 里的沉淀结果。

        FreeRAG 本身只做低成本原材料收集。Codex/Claude Code 的 MyRAG skill 负责多视角深读、OCR、转写、抽取、综合和长期沉淀。
        """
        try? body.write(to: readme, atomically: true, encoding: .utf8)
    }
}

struct WindowInfo {
    let app: String
    let title: String
    let rect: CGRect

    var displayTitle: String { title.isEmpty || title == "missing value" ? app : title }
    var hasUsableRect: Bool { rect.width > 80 && rect.height > 80 }
}

final class Platform {
    func screenGranted() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    func requestScreen() {
        _ = CGRequestScreenCaptureAccess()
        openSettings("Privacy_ScreenCapture")
    }

    func accessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibility() {
        openSettings("Privacy_Accessibility")
    }

    func micGranted() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    func micStatusText() -> String {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return "已授权"
        case .denied: return "已拒绝"
        case .restricted: return "受限制"
        case .notDetermined: return "待授权"
        @unknown default: return "未知"
        }
    }

    func requestMic(_ done: ((Bool) -> Void)? = nil) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async { done?(granted) }
        }
    }

    func openSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    func openCorpus() {
        ensureDir(corpusRoot)
        NSWorkspace.shared.open(corpusRoot)
    }

    func frontWindow() -> WindowInfo? {
        let script = """
        tell application "System Events"
            set frontApp to first application process whose frontmost is true
            set appName to name of frontApp
            try
                set frontWindow to first window of frontApp
                set winName to name of frontWindow
                set winPos to position of frontWindow
                set winSize to size of frontWindow
                return appName & "|||" & winName & "|||" & (item 1 of winPos as text) & "|||" & (item 2 of winPos as text) & "|||" & (item 1 of winSize as text) & "|||" & (item 2 of winSize as text)
            on error
                return appName & "|||" & appName & "|||0|||0|||0|||0"
            end try
        end tell
        """
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else { return nil }
            let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let p = out.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "|||")
            guard p.count == 6,
                  let x = Double(p[2]), let y = Double(p[3]),
                  let w = Double(p[4]), let h = Double(p[5]) else { return nil }
            return WindowInfo(app: p[0], title: p[1], rect: CGRect(x: x, y: y, width: w, height: h))
        } catch {
            return nil
        }
    }

    func capture(_ info: WindowInfo?, to url: URL) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        var args = ["-x"]
        if let info, info.hasUsableRect {
            let r = info.rect
            args += ["-R", "\(Int(r.minX)),\(Int(r.minY)),\(Int(r.width)),\(Int(r.height))"]
        }
        args.append(url.path)
        task.arguments = args
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0 && FileManager.default.fileExists(atPath: url.path)
        } catch {
            return false
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) throws {
        ensureDir(launchAgentURL.deletingLastPathComponent())
        if enabled {
            let exe = Bundle.main.executableURL?.path ?? CommandLine.arguments[0]
            let plist = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
              <key>Label</key><string>com.acegent.freerag</string>
              <key>ProgramArguments</key><array><string>\(exe)</string></array>
              <key>RunAtLoad</key><true/>
              <key>KeepAlive</key><false/>
            </dict>
            </plist>
            """
            try plist.write(to: launchAgentURL, atomically: true, encoding: .utf8)
        } else {
            try? FileManager.default.removeItem(at: launchAgentURL)
        }
    }

    func launchAtLoginEnabled() -> Bool {
        FileManager.default.fileExists(atPath: launchAgentURL.path)
    }
}

final class GlyphButton: NSButton {
    enum Glyph { case record, shot, mic, pause, play, stop, folder, hide }
    var glyph: Glyph
    var accent: NSColor?
    var muted = false
    var onAction: (() -> Void)?
    private var tracking: NSTrackingArea?
    private var hovering = false

    override var isHidden: Bool {
        didSet {
            if isHidden {
                hovering = false
                isHighlighted = false
                needsDisplay = true
            }
        }
    }

    init(_ glyph: Glyph, tip: String, muted: Bool = false, action: @escaping () -> Void) {
        self.glyph = glyph
        self.muted = muted
        self.onAction = action
        super.init(frame: NSRect(x: 0, y: 0, width: 30, height: 30))
        isBordered = false
        title = ""
        toolTip = tip
        target = self
        self.action = #selector(runAction)
        image = nil
        imagePosition = .imageOnly
        setButtonType(.momentaryChange)
    }

    required init?(coder: NSCoder) { nil }

    @objc private func runAction() { onAction?() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        hovering = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hovering = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        needsDisplay = true
        super.mouseDown(with: event)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 3, dy: 3)
        let fill: NSColor
        if isHighlighted {
            fill = NSColor.labelColor.withAlphaComponent(0.14)
        } else if hovering {
            fill = NSColor.labelColor.withAlphaComponent(0.08)
        } else {
            fill = .clear
        }
        fill.setFill()
        NSBezierPath(roundedRect: r, xRadius: 9, yRadius: 9).fill()

        guard let raw = NSImage(systemSymbolName: glyph.symbolName, accessibilityDescription: nil) else { return }
        let size: CGFloat = muted ? 15 : 16
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: .medium)
        let symbol = raw.withSymbolConfiguration(config) ?? raw
        let color = (accent ?? (muted ? NSColor.secondaryLabelColor : NSColor.labelColor))
            .withAlphaComponent(muted ? 0.74 : 0.90)
        let tinted = symbol.tinted(color)
        let iconRect = NSRect(
            x: bounds.midX - size / 2,
            y: bounds.midY - size / 2 - (isHighlighted ? 1 : 0),
            width: size,
            height: size
        )
        tinted.drawAspectFit(in: iconRect)
    }
}

extension NSImage {
    func tinted(_ color: NSColor) -> NSImage {
        let copy = self.copy() as? NSImage ?? self
        copy.lockFocus()
        color.set()
        NSRect(origin: .zero, size: copy.size).fill(using: .sourceAtop)
        copy.unlockFocus()
        copy.isTemplate = false
        return copy
    }

    func drawAspectFit(in rect: NSRect) {
        let source = size
        guard source.width > 0, source.height > 0 else { return }
        let scale = min(rect.width / source.width, rect.height / source.height)
        let fitted = NSRect(
            x: rect.midX - source.width * scale / 2,
            y: rect.midY - source.height * scale / 2,
            width: source.width * scale,
            height: source.height * scale
        )
        draw(in: fitted, from: .zero, operation: .sourceOver, fraction: 1.0, respectFlipped: true, hints: nil)
    }
}

extension GlyphButton.Glyph {
    var symbolName: String {
        switch self {
        case .record: return "circle"
        case .shot: return "camera"
        case .mic: return "mic"
        case .pause: return "pause.fill"
        case .play: return "play.fill"
        case .stop: return "stop.fill"
        case .folder: return "folder"
        case .hide: return "circle.dotted"
        }
    }
}

final class HUDView: NSVisualEffectView {
    var modeName = "idle" { didSet { needsDisplay = true } }
    var progress: CGFloat = 0 { didSet { needsDisplay = true } }
    var separatorX: CGFloat = 0 { didSet { needsDisplay = true } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .hudWindow
        blendingMode = .behindWindow
        self.state = .active
        wantsLayer = true
        layer?.cornerRadius = frameRect.height / 2
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        layer?.cornerRadius = bounds.height / 2
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        var origin = window.frame.origin
        origin.x += event.deltaX
        origin.y -= event.deltaY
        window.setFrameOrigin(origin)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: bounds.height / 2, yRadius: bounds.height / 2)
        let stroke: NSColor
        switch modeName {
        case "recording": stroke = NSColor.systemTeal.withAlphaComponent(0.52)
        case "voicing": stroke = NSColor.systemGreen.withAlphaComponent(0.50)
        case "paused": stroke = NSColor.systemOrange.withAlphaComponent(0.48)
        default: stroke = NSColor.separatorColor.withAlphaComponent(0.42)
        }
        stroke.setStroke(); path.lineWidth = 1; path.stroke()
        if separatorX > 0 {
            NSColor.separatorColor.withAlphaComponent(0.7).setStroke()
            let p = NSBezierPath()
            p.move(to: NSPoint(x: separatorX, y: 10)); p.line(to: NSPoint(x: separatorX, y: bounds.height - 10)); p.stroke()
        }
        if progress > 0 {
            NSColor.systemGreen.withAlphaComponent(0.7).setFill()
            NSBezierPath(roundedRect: NSRect(x: 7, y: 4, width: max(4, (bounds.width - 14) * progress), height: 2), xRadius: 1, yRadius: 1).fill()
        }
    }
}

final class HUDCounterView: NSView {
    var value = "" { didSet { needsDisplay = true } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard !value.isEmpty else { return }
        let p = NSMutableParagraphStyle()
        p.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: p
        ]
        let size = (value as NSString).size(withAttributes: attrs)
        let textRect = NSRect(
            x: 0,
            y: floor((bounds.height - size.height) / 2) - 0.5,
            width: bounds.width,
            height: ceil(size.height) + 2
        )
        (value as NSString).draw(in: textRect, withAttributes: attrs)
    }
}

final class ClipboardWatcher {
    private let store: CorpusStore
    private var timer: Timer?
    private var lastChange = NSPasteboard.general.changeCount
    private var lastHash = ""
    private let seenURL = clipRoot.appendingPathComponent("_recent_hashes.json")
    private var recentHashes: [String] = []

    init(store: CorpusStore) {
        self.store = store
    }

    func start() {
        ensureDir(clipRoot)
        if let data = try? Data(contentsOf: seenURL),
           let hashes = try? JSONSerialization.jsonObject(with: data) as? [String] {
            recentHashes = Array(hashes.suffix(300))
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func shouldSave(hash: String) -> Bool {
        guard hash != lastHash, !recentHashes.contains(hash) else { return false }
        lastHash = hash
        recentHashes.append(hash)
        if recentHashes.count > 300 {
            recentHashes.removeFirst(recentHashes.count - 300)
        }
        writeJSON(recentHashes, to: seenURL)
        return true
    }

    private func tick() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChange else { return }
        lastChange = pb.changeCount

        if let text = pb.string(forType: .string) {
            let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { return }
            let data = Data(normalized.utf8)
            guard data.count <= 1_000_000 else { return }
            let hash = sha256Hex(data)
            guard shouldSave(hash: hash) else { return }
            saveText(text)
            return
        }

        if let data = pb.data(forType: .tiff),
           let rep = NSBitmapImageRep(data: data) {
            let pixels = rep.pixelsWide * rep.pixelsHigh
            guard pixels <= 32_000_000, data.count <= 96_000_000 else { return }
            let hash = sha256Hex(data)
            guard shouldSave(hash: hash) else { return }
            saveImage(rep: rep, sourceBytes: data.count)
        }
    }

    private func saveText(_ text: String) {
        let id = uniqueID("text")
        let dir = clipRoot.appendingPathComponent(id)
        ensureDir(dir)
        try? text.write(to: dir.appendingPathComponent("content.md"), atomically: true, encoding: .utf8)
        writeJSON(["time": nowISO(), "type": "text", "length": text.count], to: dir.appendingPathComponent("_meta.json"))
        writeLLMContext(
            title: "剪贴板文字 \(id)",
            type: "clipboard/text",
            summary: String(text.prefix(500)),
            files: ["content.md", "_meta.json"],
            to: dir
        )
        store.addEntry([
            "id": id, "type": "clipboard", "subtype": "text", "time": nowISO(),
            "title": "", "tags": [], "summary": String(text.prefix(150)), "path": "clipboard/\(id)/"
        ])
    }

    private func saveImage(rep: NSBitmapImageRep, sourceBytes: Int) {
        let id = uniqueID("image")
        let dir = clipRoot.appendingPathComponent(id)
        ensureDir(dir)
        guard let png = rep.representation(using: .png, properties: [.compressionFactor: 0.92]) else { return }
        let imageURL = dir.appendingPathComponent("image.png")
        guard (try? png.write(to: imageURL)) != nil else { return }
        try? "![剪贴板图片](image.png)\n".write(to: dir.appendingPathComponent("content.md"), atomically: true, encoding: .utf8)
        writeJSON([
            "time": nowISO(), "type": "image",
            "width": rep.pixelsWide, "height": rep.pixelsHigh,
            "source_bytes": sourceBytes, "png_bytes": png.count
        ], to: dir.appendingPathComponent("_meta.json"))
        writeLLMContext(
            title: "剪贴板图片 \(id)",
            type: "clipboard/image",
            summary: "从剪贴板保存的图片，可供后续 OCR、视觉阅读或语境分析。",
            files: ["image.png", "content.md", "_meta.json"],
            to: dir
        )
        store.addEntry([
            "id": id, "type": "clipboard", "subtype": "image", "time": nowISO(),
            "title": "", "tags": [], "summary": "剪贴板图片", "path": "clipboard/\(id)/"
        ])
    }
}

func imageSignature(at url: URL) -> [UInt8]? {
    guard let image = NSImage(contentsOf: url),
          let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
    let width = 32
    let height = 32
    var pixels = [UInt8](repeating: 0, count: width * height)
    let colorSpace = CGColorSpaceCreateDeviceGray()
    pixels.withUnsafeMutableBytes { raw in
        guard let ctx = CGContext(
            data: raw.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return }
        ctx.interpolationQuality = .low
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    let avg = pixels.reduce(0) { $0 + Int($1) } / max(1, pixels.count)
    return pixels.map { $0 > UInt8(avg) ? 1 : 0 }
}

func signatureDistance(_ a: [UInt8], _ b: [UInt8]) -> Double {
    guard a.count == b.count, !a.isEmpty else { return 1.0 }
    let diff = zip(a, b).reduce(0) { $0 + ($1.0 == $1.1 ? 0 : 1) }
    return Double(diff) / Double(a.count)
}

func makeScreenStoryboards(captures: [[String: Any]], in dir: URL, outputDir: URL) -> [String] {
    let pageSize = 8
    let chunks = stride(from: 0, to: captures.count, by: pageSize).map {
        Array(captures[$0..<min($0 + pageSize, captures.count)])
    }
    var outputs: [String] = []
    for (pageIndex, chunk) in chunks.enumerated() {
        let loaded: [(cap: [String: Any], image: NSImage)] = chunk.compactMap { cap in
            guard let file = cap["file"] as? String,
                  let image = NSImage(contentsOf: dir.appendingPathComponent(file)) else { return nil }
            return (cap, image)
        }
        guard !loaded.isEmpty else { continue }
        let maxSourceWidth = loaded.map { $0.image.size.width }.max() ?? 1200
        let targetWidth = min(max(800, maxSourceWidth), 1440)
        let labelHeight: CGFloat = 30
        let gap: CGFloat = 12
        let scaledHeights = loaded.map { item in
            max(1, item.image.size.height * targetWidth / max(1, item.image.size.width))
        }
        let totalHeight = scaledHeights.reduce(CGFloat(0), +) + CGFloat(loaded.count) * labelHeight + CGFloat(max(0, loaded.count - 1)) * gap
        let storyboard = NSImage(size: NSSize(width: targetWidth, height: totalHeight))
        storyboard.lockFocus()
        NSColor.windowBackgroundColor.setFill()
        NSRect(x: 0, y: 0, width: targetWidth, height: totalHeight).fill()
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        var y = totalHeight
        for (idx, item) in loaded.enumerated() {
            let label = "\(item.cap["seq"] ?? idx + 1)  \(item.cap["time"] ?? "")  \(item.cap["title"] ?? "")"
            y -= labelHeight
            (label as NSString).draw(
                at: NSPoint(x: 14, y: y + 8),
                withAttributes: titleAttrs
            )
            let h = scaledHeights[idx]
            y -= h
            item.image.draw(in: NSRect(x: 0, y: y, width: targetWidth, height: h), from: .zero, operation: .sourceOver, fraction: 1.0)
            y -= gap
        }
        storyboard.unlockFocus()
        guard let tiff = storyboard.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [.compressionFactor: 0.92]) else { continue }
        let filename = "storyboard_\(String(format: "%02d", pageIndex + 1)).png"
        try? png.write(to: outputDir.appendingPathComponent(filename))
        outputs.append("stitched/\(filename)")
    }
    return outputs
}

final class ScreenCollector {
    private let platform: Platform
    private let store: CorpusStore
    private let queue = DispatchQueue(label: "com.acegent.freerag.screen")
    private var timer: Timer?
    private var dir: URL?
    private var session = ""
    private var caps: [[String: Any]] = []
    private var count = 0
    private var stable = 0
    private var lastSignature: [UInt8]?
    private var paused = false
    var onCount: ((Int) -> Void)?
    var onDone: ((String) -> Void)?

    init(platform: Platform, store: CorpusStore) {
        self.platform = platform
        self.store = store
    }

    func start() {
        prepareSession()
        capture(force: true)
        schedule()
    }

    private func prepareSession() {
        let info = platform.frontWindow()
        session = "\(uniqueID())_\(sanitize(info?.displayTitle ?? "screen"))"
        dir = screenRoot.appendingPathComponent(session)
        ensureDir(dir!)
        caps = []
        count = 0
        stable = 0
        lastSignature = nil
        paused = false
    }

    private func schedule() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.6, repeats: true) { [weak self] _ in self?.capture(force: false) }
    }

    func pause() {
        paused = true
        timer?.invalidate()
        timer = nil
    }

    func resume() {
        guard dir != nil else { return }
        paused = false
        schedule()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        queue.async { [weak self] in
            DispatchQueue.main.async { self?.pipeline() }
        }
    }

    func single() {
        prepareSession()
        capture(force: true)
        pipeline()
    }

    private func capture(force: Bool) {
        guard let dir, !paused else { return }
        queue.async { [weak self] in
            guard let self, !self.paused else { return }
            let info = self.platform.frontWindow()
            let file = "\(String(format: "%03d", self.count + 1)).png"
            let url = dir.appendingPathComponent(file)
            guard self.platform.capture(info, to: url) else { return }
            if !force, let signature = imageSignature(at: url) {
                if let lastSignature = self.lastSignature, signatureDistance(signature, lastSignature) < 0.025 {
                    self.stable += 1
                    try? FileManager.default.removeItem(at: url)
                    return
                }
                self.lastSignature = signature
            } else if force {
                self.lastSignature = imageSignature(at: url)
            }
            self.count += 1
            self.caps.append(["seq": self.count, "file": file, "title": info?.displayTitle ?? "screen", "time": nowISO()])
            DispatchQueue.main.async { self.onCount?(self.count) }
        }
    }

    private func finishPipeline() {
        queue.async { [weak self] in
            guard let self else { return }
            guard let dir = self.dir else {
                DispatchQueue.main.async { self.onDone?("没有截图") }
                return
            }
            guard self.count > 0 else {
                DispatchQueue.main.async { self.onDone?("没有可保存截图") }
                return
            }
            let stitched = dir.appendingPathComponent("stitched")
            ensureDir(stitched)
            let storyboardFiles = makeScreenStoryboards(captures: self.caps, in: dir, outputDir: stitched)
            writeJSON(self.caps, to: dir.appendingPathComponent("captures.json"))
            let meta: [String: Any] = [
                "session": self.session, "time": nowISO(), "count": self.count, "deduped": self.stable, "storyboards": storyboardFiles,
                "titles": Array(Set(self.caps.compactMap { $0["title"] as? String })),
                "summary": "\(self.count) 张有效截图，过滤 \(self.stable) 张近似重复画面", "platform": "macos-native"
            ]
            writeJSON(meta, to: dir.appendingPathComponent("_meta.json"))
            writeLLMContext(
                title: self.caps.first?["title"] as? String ?? self.session,
                type: "screen",
                summary: "\(self.count) 张去重后的屏幕证据。storyboard 按时间顺序保留画面，供后续 LLM 阅读、OCR、复盘或信息抽取。",
                files: storyboardFiles + ["captures.json", "_meta.json"],
                to: dir
            )
            self.store.addEntry([
                "id": self.session, "type": "screen", "time": nowISO(),
                "title": self.caps.first?["title"] as? String ?? "screen",
                "tags": [], "summary": meta["summary"]!, "path": "screen/\(self.session)/"
            ])
            DispatchQueue.main.async { self.onDone?("已保存 \(self.count) 张") }
        }
    }

    private func pipeline() {
        finishPipeline()
    }
}

final class VoiceRecorder: NSObject, AVAudioRecorderDelegate {
    private let store: CorpusStore
    private var recorder: AVAudioRecorder?
    private var runningSince: Date?
    private var accumulated: TimeInterval = 0
    private var dir: URL?
    var onTick: ((Int) -> Void)?
    var onDone: ((String) -> Void)?
    private var timer: Timer?

    init(store: CorpusStore) { self.store = store }

    func start() {
        ensureDir(voiceRoot)
        let id = uniqueID("voice")
        dir = voiceRoot.appendingPathComponent(id)
        ensureDir(dir!)
        accumulated = 0
        let url = dir!.appendingPathComponent("recording.wav")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false
        ]
        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.delegate = self
            recorder?.record()
            runningSince = Date()
            startTimer()
        } catch {
            onDone?("麦克风不可用")
        }
    }

    private func elapsed() -> TimeInterval {
        accumulated + (runningSince.map { Date().timeIntervalSince($0) } ?? 0)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.onTick?(Int(self.elapsed()))
        }
    }

    func pause() {
        guard recorder?.isRecording == true else { return }
        if let runningSince {
            accumulated += Date().timeIntervalSince(runningSince)
        }
        runningSince = nil
        recorder?.pause()
        timer?.invalidate()
        timer = nil
        onTick?(Int(elapsed()))
    }

    func resume() {
        guard let recorder, !recorder.isRecording else { return }
        recorder.record()
        runningSince = Date()
        startTimer()
    }

    func stop() {
        if let runningSince {
            accumulated += Date().timeIntervalSince(runningSince)
        }
        runningSince = nil
        recorder?.stop()
        timer?.invalidate()
        timer = nil
        guard let dir else { return }
        let duration = accumulated
        writeJSON(["time": nowISO(), "duration": duration, "sample_rate": 16000, "channels": 1], to: dir.appendingPathComponent("_meta.json"))
        let id = dir.lastPathComponent
        try? "# 录音 \(id)\n时长: \(Int(duration))s\n\n*(待转译)*\n".write(to: dir.appendingPathComponent("transcript.md"), atomically: true, encoding: .utf8)
        writeLLMContext(
            title: "录音 \(id)",
            type: "voice",
            summary: "本地语音笔记，时长 \(Int(duration)) 秒。当前保存原始录音，转写可由后续 LLM/语音工具补齐。",
            files: ["recording.wav", "transcript.md", "_meta.json"],
            to: dir
        )
        store.addEntry([
            "id": id, "type": "voice", "time": nowISO(), "title": "录音 \(id)",
            "tags": [], "summary": "时长 \(Int(duration))s", "path": "voice/\(id)/"
        ])
        onDone?("录音已保存 \(Int(duration))s")
    }
}

final class HUDController {
    let panel: NSPanel
    let view = HUDView(frame: NSRect(x: 0, y: 0, width: 248, height: 42))
    let counter = HUDCounterView(frame: NSRect(x: 0, y: 0, width: 52, height: 30))
    var state = "idle"
    var buttons: [GlyphButton] = []
    var onRecord: (() -> Void)?
    var onShot: (() -> Void)?
    var onMic: (() -> Void)?
    var onPause: (() -> Void)?
    var onResume: (() -> Void)?
    var onStop: (() -> Void)?
    var onFolder: (() -> Void)?
    var onHide: (() -> Void)?

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 248, height: 42), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.contentView = view
        build()
    }

    private func build() {
        view.addSubview(counter)
        relayout()
    }

    private func make(_ g: GlyphButton.Glyph, tip: String, muted: Bool = false, action: @escaping () -> Void) -> GlyphButton {
        let b = GlyphButton(g, tip: tip, muted: muted, action: action)
        view.addSubview(b)
        buttons.append(b)
        return b
    }

    func show() {
        if buttons.isEmpty {
            _ = make(.record, tip: "连续收集") { [weak self] in self?.onRecord?() }
            _ = make(.shot, tip: "单次截图") { [weak self] in self?.onShot?() }
            _ = make(.mic, tip: "录音") { [weak self] in self?.onMic?() }
            _ = make(.pause, tip: "暂停") { [weak self] in self?.onPause?() }
            _ = make(.play, tip: "继续") { [weak self] in self?.onResume?() }
            _ = make(.stop, tip: "完成") { [weak self] in self?.onStop?() }
            _ = make(.folder, tip: "打开语料库", muted: true) { [weak self] in self?.onFolder?() }
            _ = make(.hide, tip: "隐藏", muted: true) { [weak self] in self?.onHide?() }
        }
        relayout()
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: f.maxX - panel.frame.width - 28, y: f.maxY - 64))
        }
        panel.orderFrontRegardless()
    }

    func setState(_ s: String, count: String = "") {
        state = s
        view.modeName = s
        counter.value = count
        panel.level = s == "idle" ? .statusBar : .screenSaver
        relayout()
    }

    private func relayout() {
        let rec = buttons.indices.contains(0) ? buttons[0] : nil
        let shot = buttons.indices.contains(1) ? buttons[1] : nil
        let mic = buttons.indices.contains(2) ? buttons[2] : nil
        let pause = buttons.indices.contains(3) ? buttons[3] : nil
        let play = buttons.indices.contains(4) ? buttons[4] : nil
        let stop = buttons.indices.contains(5) ? buttons[5] : nil
        let folder = buttons.indices.contains(6) ? buttons[6] : nil
        let hide = buttons.indices.contains(7) ? buttons[7] : nil
        buttons.forEach { $0.isHidden = true; $0.accent = nil }
        var visible: [NSView] = []
        view.separatorX = 0
        switch state {
        case "recording":
            counter.isHidden = false
            pause?.isHidden = false; stop?.isHidden = false; stop?.accent = .systemRed
            visible = [counter, pause, stop].compactMap { $0 }
        case "voicing":
            counter.isHidden = false
            pause?.isHidden = false; stop?.isHidden = false; stop?.accent = .systemRed
            visible = [counter, pause, stop].compactMap { $0 }
        case "paused":
            counter.isHidden = false
            play?.isHidden = false; stop?.isHidden = false; play?.accent = .systemGreen; stop?.accent = .systemRed
            visible = [counter, play, stop].compactMap { $0 }
        default:
            counter.isHidden = true
            rec?.isHidden = false; shot?.isHidden = false; mic?.isHidden = false
            visible = [rec, shot, mic].compactMap { $0 }
        }
        folder?.isHidden = false; hide?.isHidden = false
        visible += [folder, hide].compactMap { $0 }
        var x: CGFloat = 10
        for (i, v) in visible.enumerated() {
            if i == visible.count - 2 {
                view.separatorX = x + 2
                x += 8
            }
            let w: CGFloat = v === counter ? 52 : 30
            v.frame = NSRect(x: x, y: 6, width: w, height: 30)
            x += w + 4
        }
        let width = x + 6
        panel.setContentSize(NSSize(width: width, height: 42))
        view.frame = NSRect(x: 0, y: 0, width: width, height: 42)
        view.needsDisplay = true
    }
}

final class SettingsRootView: NSView {
    override var isOpaque: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()
    }
}

final class StatusBadge: NSView {
    private var text = ""
    private var ok = false

    init() {
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { nil }

    func set(_ text: String, ok: Bool) {
        self.text = text
        self.ok = ok
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let color = ok ? NSColor.systemGreen : NSColor.systemOrange
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        color.withAlphaComponent(0.11).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()

        let p = NSMutableParagraphStyle()
        p.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: color,
            .paragraphStyle: p
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let textRect = NSRect(x: 0, y: floor((bounds.height - size.height) / 2) - 0.5, width: bounds.width, height: ceil(size.height) + 2)
        (text as NSString).draw(in: textRect, withAttributes: attrs)
    }
}

final class SettingsWindow: NSWindowController {
    let platform: Platform
    let screenStatus = StatusBadge()
    let accessStatus = StatusBadge()
    let micStatus = StatusBadge()
    let launchCheck = NSButton(checkboxWithTitle: "登录时自动启动 FreeRAG", target: nil, action: nil)
    var screenButton: NSButton?
    var accessButton: NSButton?
    var micButton: NSButton?
    var restartButton: NSButton?

    init(platform: Platform) {
        self.platform = platform
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 460), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        let root = SettingsRootView(frame: NSRect(x: 0, y: 0, width: 620, height: 460))
        w.contentView = root
        w.isOpaque = true
        w.backgroundColor = .windowBackgroundColor
        super.init(window: w)
        w.title = "FreeRAG 设置"
        w.center()
        build(in: root)
        refresh()
    }

    required init?(coder: NSCoder) { nil }

    private func build(in content: NSView) {
        let title = label("FreeRAG", size: 22, weight: .semibold, color: .labelColor)
        title.frame = NSRect(x: 40, y: 394, width: 220, height: 30)
        content.addSubview(title)

        let sub = label("一次性准备权限，之后用浮窗安静收集屏幕、剪贴板和语音语料。", size: 13, weight: .regular, color: .secondaryLabelColor)
        sub.frame = NSRect(x: 40, y: 366, width: 540, height: 22)
        content.addSubview(sub)

        addSeparator(y: 344, in: content)
        addPermissionRow(y: 286, title: "屏幕录制", detail: "保存截图和连续屏幕证据", badge: screenStatus, buttonTitle: "打开", action: #selector(openScreenSettings), in: content)
        addSeparator(y: 258, in: content)
        addPermissionRow(y: 200, title: "辅助功能", detail: "识别当前窗口标题和区域", badge: accessStatus, buttonTitle: "打开", action: #selector(openAccessibilitySettings), in: content)
        addSeparator(y: 172, in: content)
        addPermissionRow(y: 114, title: "麦克风", detail: "录制本地语音笔记", badge: micStatus, buttonTitle: "准备", action: #selector(prepareMic), in: content)
        addSeparator(y: 86, in: content)

        let prepare = NSButton(title: "全部准备", target: self, action: #selector(preparePermissions))
        prepare.bezelStyle = .rounded
        prepare.keyEquivalent = "\r"
        prepare.frame = NSRect(x: 40, y: 22, width: 116, height: 32)
        content.addSubview(prepare)

        let refresh = NSButton(title: "刷新", target: self, action: #selector(refreshAction))
        refresh.bezelStyle = .rounded
        refresh.frame = NSRect(x: 168, y: 22, width: 88, height: 32)
        content.addSubview(refresh)

        launchCheck.target = self
        launchCheck.action = #selector(toggleLaunch)
        launchCheck.frame = NSRect(x: 40, y: 56, width: 260, height: 24)
        content.addSubview(launchCheck)

        let restart = NSButton(title: "重启", target: self, action: #selector(restartApp))
        restart.bezelStyle = .rounded
        restart.frame = NSRect(x: 514, y: 22, width: 66, height: 32)
        content.addSubview(restart)
        restartButton = restart

        let hint = label("授权后若仍未生效，请重启 FreeRAG。", size: 12, weight: .regular, color: .tertiaryLabelColor)
        hint.alignment = .right
        hint.frame = NSRect(x: 286, y: 27, width: 218, height: 20)
        content.addSubview(hint)

        let signature = label("八路出品 凑合能用", size: 10, weight: .regular, color: .tertiaryLabelColor)
        signature.alignment = .center
        signature.frame = NSRect(x: 200, y: 4, width: 220, height: 14)
        content.addSubview(signature)
    }

    private func addPermissionRow(y: CGFloat, title: String, detail: String, badge: StatusBadge, buttonTitle: String, action: Selector, in content: NSView) {
        let titleLabel = label(title, size: 14, weight: .semibold, color: .labelColor)
        titleLabel.frame = NSRect(x: 40, y: y + 16, width: 220, height: 22)
        content.addSubview(titleLabel)

        let detailLabel = label(detail, size: 12, weight: .regular, color: .secondaryLabelColor)
        detailLabel.frame = NSRect(x: 40, y: y - 4, width: 300, height: 20)
        content.addSubview(detailLabel)

        badge.frame = NSRect(x: 370, y: y + 7, width: 86, height: 26)
        content.addSubview(badge)

        let button = NSButton(title: buttonTitle, target: self, action: action)
        button.bezelStyle = .rounded
        button.frame = NSRect(x: 484, y: y + 5, width: 96, height: 30)
        content.addSubview(button)
        if title == "屏幕录制" {
            screenButton = button
        } else if title == "辅助功能" {
            accessButton = button
        } else if title == "麦克风" {
            micButton = button
        }
    }

    private func addSeparator(y: CGFloat, in content: NSView) {
        let line = NSBox(frame: NSRect(x: 40, y: y, width: 540, height: 1))
        line.boxType = .separator
        content.addSubview(line)
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = .systemFont(ofSize: size, weight: weight)
        l.textColor = color
        l.backgroundColor = .clear
        l.drawsBackground = false
        return l
    }

    @objc func openScreenSettings() {
        platform.requestScreen()
        refresh()
    }

    @objc func openAccessibilitySettings() {
        platform.requestAccessibility()
        refresh()
    }

    @objc func prepareMic() {
        platform.requestMic { [weak self] _ in self?.refresh() }
    }

    @objc func preparePermissions() {
        platform.requestScreen()
        platform.requestAccessibility()
        platform.requestMic { [weak self] _ in self?.refresh() }
    }

    @objc func refreshAction() { refresh() }

    @objc func toggleLaunch() {
        try? platform.setLaunchAtLogin(launchCheck.state == .on)
        refresh()
    }

    @objc func restartApp() {
        guard let bundleURL = Bundle.main.bundleURL as URL? else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = [bundleURL.path]
        try? task.run()
        NSApp.terminate(nil)
    }

    func refresh() {
        launchCheck.state = platform.launchAtLoginEnabled() ? .on : .off
        let screenOK = platform.screenGranted()
        let accessOK = platform.accessibilityGranted()
        let micOK = platform.micGranted()
        screenStatus.set(screenOK ? "已就绪" : "未生效", ok: screenOK)
        accessStatus.set(accessOK ? "已就绪" : "未生效", ok: accessOK)
        micStatus.set(platform.micStatusText(), ok: platform.micGranted())
        screenButton?.isEnabled = !screenOK
        accessButton?.isEnabled = !accessOK
        micButton?.isEnabled = !micOK
        restartButton?.isHidden = screenOK && accessOK && micOK
    }
}

final class LibraryWindow: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private let table = NSTableView()
    private let detail = NSTextView()
    private let filter = NSSegmentedControl(labels: ["全部", "屏幕", "剪贴板", "语音"], trackingMode: .selectOne, target: nil, action: nil)
    private let search = NSSearchField(frame: .zero)
    private let countLabel = NSTextField(labelWithString: "")
    private var entries: [[String: Any]] = []
    private var visible: [[String: Any]] = []

    init() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 520), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        let root = SettingsRootView(frame: NSRect(x: 0, y: 0, width: 820, height: 520))
        w.contentView = root
        w.minSize = NSSize(width: 760, height: 460)
        w.title = "FreeRAG 原材料库"
        super.init(window: w)
        build(in: root)
        refresh()
    }

    required init?(coder: NSCoder) { nil }

    private func build(in content: NSView) {
        let title = NSTextField(labelWithString: "原材料库")
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        title.frame = NSRect(x: 28, y: 470, width: 180, height: 28)
        content.addSubview(title)

        filter.selectedSegment = 0
        filter.target = self
        filter.action = #selector(filterChanged)
        filter.frame = NSRect(x: 28, y: 432, width: 250, height: 30)
        content.addSubview(filter)

        search.placeholderString = "搜索原材料标题、摘要、上下文"
        search.delegate = self
        search.target = self
        search.action = #selector(searchChanged)
        search.frame = NSRect(x: 292, y: 432, width: 250, height: 30)
        content.addSubview(search)

        countLabel.textColor = .secondaryLabelColor
        countLabel.alignment = .right
        countLabel.frame = NSRect(x: 560, y: 436, width: 230, height: 22)
        content.addSubview(countLabel)

        table.headerView = nil
        table.rowHeight = 44
        table.delegate = self
        table.dataSource = self
        table.usesAlternatingRowBackgroundColors = false
        addColumn("time", width: 132)
        addColumn("type", width: 62)
        addColumn("state", width: 54)
        addColumn("title", width: 212)

        let tableScroll = NSScrollView(frame: NSRect(x: 28, y: 78, width: 460, height: 338))
        tableScroll.documentView = table
        tableScroll.hasVerticalScroller = true
        tableScroll.borderType = .lineBorder
        content.addSubview(tableScroll)

        detail.isEditable = false
        detail.isSelectable = true
        detail.font = .systemFont(ofSize: 12)
        detail.textColor = .labelColor
        detail.backgroundColor = .textBackgroundColor
        detail.textContainerInset = NSSize(width: 12, height: 12)
        let detailScroll = NSScrollView(frame: NSRect(x: 504, y: 78, width: 288, height: 338))
        detailScroll.documentView = detail
        detailScroll.hasVerticalScroller = true
        detailScroll.borderType = .lineBorder
        content.addSubview(detailScroll)

        let refresh = NSButton(title: "刷新", target: self, action: #selector(refreshAction))
        refresh.bezelStyle = .rounded
        refresh.frame = NSRect(x: 28, y: 28, width: 82, height: 30)
        content.addSubview(refresh)

        let cleanProcessed = NSButton(title: "清理已处理", target: self, action: #selector(cleanProcessedAction))
        cleanProcessed.bezelStyle = .rounded
        cleanProcessed.frame = NSRect(x: 124, y: 28, width: 108, height: 30)
        content.addSubview(cleanProcessed)

        let openItem = NSButton(title: "打开条目", target: self, action: #selector(openSelected))
        openItem.bezelStyle = .rounded
        openItem.frame = NSRect(x: 590, y: 28, width: 92, height: 30)
        content.addSubview(openItem)

        let reveal = NSButton(title: "Finder", target: self, action: #selector(revealSelected))
        reveal.bezelStyle = .rounded
        reveal.frame = NSRect(x: 696, y: 28, width: 96, height: 30)
        content.addSubview(reveal)
    }

    private func addColumn(_ id: String, width: CGFloat) {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
        column.width = width
        table.addTableColumn(column)
    }

    @objc func refreshAction() { refresh() }
    @objc func filterChanged() { applyFilter() }
    @objc func searchChanged() { applyFilter() }
    @objc func cleanProcessedAction() { cleanProcessedRawEntries() }

    func controlTextDidChange(_ obj: Notification) {
        applyFilter()
    }

    func refresh() {
        ensureDir(corpusRoot)
        let source = FileManager.default.fileExists(atPath: libraryURL.path) ? libraryURL : indexURL
        guard let data = try? Data(contentsOf: source),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            entries = []
            applyFilter()
            return
        }
        entries = json["entries"] as? [[String: Any]] ?? []
        applyFilter()
    }

    private func applyFilter() {
        let q = search.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let selectedType: String? = {
            switch filter.selectedSegment {
            case 1: return "screen"
            case 2: return "clipboard"
            case 3: return "voice"
            default: return nil
            }
        }()
        visible = entries.filter { entry in
            if let selectedType, (entry["type"] as? String) != selectedType {
                return false
            }
            guard !q.isEmpty else { return true }
            let path = entry["path"] as? String ?? ""
            let contextURL = corpusRoot.appendingPathComponent(path).appendingPathComponent("llm_context.md")
            let context = (try? String(contentsOf: contextURL, encoding: .utf8)) ?? ""
            let haystack = [
                entry["title"] as? String ?? "",
                entry["summary"] as? String ?? "",
                entry["type"] as? String ?? "",
                context
            ].joined(separator: " ").lowercased()
            return haystack.contains(q)
        }
        table.reloadData()
        let doneCount = entries.filter { entryIsMarkedProcessed($0) }.count
        countLabel.stringValue = doneCount > 0 ? "\(visible.count) / \(entries.count) 条，已处理 \(doneCount)" : "\(visible.count) / \(entries.count) 条"
        if visible.isEmpty {
            detail.string = "还没有匹配的原材料。"
        } else if table.selectedRow < 0 {
            table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        } else {
            updateDetail()
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int { visible.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < visible.count, let tableColumn else { return nil }
        let id = tableColumn.identifier.rawValue
        let value = displayValue(for: visible[row], column: id)
        let cell = NSTextField(labelWithString: value)
        cell.lineBreakMode = .byTruncatingTail
        cell.font = id == "title" ? .systemFont(ofSize: 12, weight: .medium) : .systemFont(ofSize: 11)
        cell.textColor = id == "type" ? .secondaryLabelColor : .labelColor
        return cell
    }

    private func displayValue(for entry: [String: Any], column: String) -> String {
        switch column {
        case "time":
            return String((entry["time"] as? String ?? "").prefix(16)).replacingOccurrences(of: "T", with: " ")
        case "type":
            switch entry["type"] as? String {
            case "screen": return "屏幕"
            case "clipboard": return "剪贴板"
            case "voice": return "语音"
            default: return entry["type"] as? String ?? ""
            }
        case "state":
            return entryIsMarkedProcessed(entry) ? "已处理" : ""
        default:
            let title = entry["title"] as? String ?? ""
            if !title.isEmpty { return title }
            let summary = entry["summary"] as? String ?? ""
            return summary.isEmpty ? (entry["id"] as? String ?? "") : summary
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateDetail()
    }

    private func selectedEntry() -> [String: Any]? {
        let row = table.selectedRow
        guard row >= 0, row < visible.count else { return nil }
        return visible[row]
    }

    private func selectedURL() -> URL? {
        guard let entry = selectedEntry(),
              let path = entry["path"] as? String,
              !path.isEmpty else { return nil }
        return corpusRoot.appendingPathComponent(path)
    }

    private func updateDetail() {
        guard let entry = selectedEntry() else {
            detail.string = "选择一条原材料查看 LLM 上下文。"
            return
        }
        let path = entry["path"] as? String ?? ""
        let dir = corpusRoot.appendingPathComponent(path)
        let context = (try? String(contentsOf: dir.appendingPathComponent("llm_context.md"), encoding: .utf8)) ?? ""
        let body = """
        \(displayValue(for: entry, column: "title"))

        角色: 原材料
        类型: \(displayValue(for: entry, column: "type"))
        时间: \(entry["time"] as? String ?? "")
        路径: \(path)
        状态: \(entryIsMarkedProcessed(entry) ? "已处理，可清理原材料" : "未处理")
        建议处理输出: processed/\(entry["id"] as? String ?? "")/

        摘要:
        \(entry["summary"] as? String ?? "")

        \(context)
        """
        detail.string = body
    }

    @objc func openSelected() {
        if let url = selectedURL() {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(corpusRoot)
        }
    }

    @objc func revealSelected() {
        if let url = selectedURL() {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.open(corpusRoot)
        }
    }

    private func currentIndexEntries() -> [[String: Any]] {
        if let data = try? Data(contentsOf: indexURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let indexEntries = json["entries"] as? [[String: Any]],
           !indexEntries.isEmpty {
            return indexEntries
        }
        return entries
    }

    private func cleanProcessedRawEntries() {
        let sourceEntries = currentIndexEntries()
        let removable = sourceEntries.filter { entry in
            guard rawEntryURL(for: entry) != nil else { return false }
            return entryHasRawProcessedMarker(entry)
        }
        guard !removable.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "没有可清理的已处理语料"
            alert.informativeText = "MyRAG 完成处理后会写入 \(rawProcessedMarkerName)，FreeRAG 只清理带标记的原材料。"
            alert.runModal()
            return
        }

        let alert = NSAlert()
        alert.messageText = "清理已处理过的原材料？"
        alert.informativeText = "将删除 \(removable.count) 个带 \(rawProcessedMarkerName) 标记的 screen/clipboard/voice 原材料目录；processed/ 里的沉淀结果会保留。"
        alert.addButton(withTitle: "清理")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let removableIDs = Set(removable.compactMap { $0["id"] as? String })
        let fm = FileManager.default
        var removed = 0
        for entry in removable {
            if let url = rawEntryURL(for: entry), fm.fileExists(atPath: url.path) {
                do {
                    try fm.removeItem(at: url)
                    removed += 1
                } catch {
                    NSLog("FreeRAG failed to remove processed raw entry %@: %@", url.path, String(describing: error))
                }
            }
        }

        let remaining = sourceEntries.filter { entry in
            guard let id = entry["id"] as? String else { return true }
            return !removableIDs.contains(id)
        }
        writeCorpusIndexAndLibrary(remaining)
        refresh()

        let done = NSAlert()
        done.messageText = "已清理 \(removed) 个原材料目录"
        done.informativeText = "处理结果仍保留在 ~/Documents/Corpus/processed/。"
        done.runModal()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    let platform = Platform()
    let store = CorpusStore()
    lazy var clipboard = ClipboardWatcher(store: store)
    lazy var screen = ScreenCollector(platform: platform, store: store)
    lazy var voice = VoiceRecorder(store: store)
    let hud = HUDController()
    var settings: SettingsWindow?
    var library: LibraryWindow?
    var status: NSStatusItem!
    var mode = "idle"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenu()
        setupHUD()
        clipboard.start()
        hud.show()
        if !platform.screenGranted() || !platform.accessibilityGranted() || !platform.micGranted() {
            showSettings()
        }
    }

    func setupMenu() {
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image: NSImage?
        if let iconURL = Bundle.main.url(forResource: "StatusIcon", withExtension: "png") {
            image = NSImage(contentsOf: iconURL)
        } else {
            image = NSImage(systemSymbolName: "square.stack.3d.down.right", accessibilityDescription: "FreeRAG")
        }
        image?.size = NSSize(width: 18, height: 18)
        image?.isTemplate = true
        status.button?.image = image
        status.button?.toolTip = "FreeRAG 正在收集剪贴板语料"
        let menu = NSMenu()
        menu.addItem(menuItem("显示浮窗", #selector(showHUD)))
        menu.addItem(.separator())
        menu.addItem(menuItem("连续收集", #selector(startRecordAction)))
        menu.addItem(menuItem("单次截图", #selector(singleShotAction)))
        menu.addItem(menuItem("录音", #selector(startVoiceAction)))
        menu.addItem(menuItem("暂停", #selector(pauseAction)))
        menu.addItem(menuItem("继续", #selector(resumeAction)))
        menu.addItem(menuItem("完成当前收集", #selector(stopAction)))
        menu.addItem(.separator())
        menu.addItem(menuItem("语料库", #selector(showLibrary)))
        menu.addItem(menuItem("在 Finder 中打开语料库", #selector(openCorpus)))
        menu.addItem(menuItem("设置...", #selector(showSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(menuItem("退出", #selector(quit), key: "q"))
        status.menu = menu
    }

    func menuItem(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(startRecordAction), #selector(singleShotAction), #selector(startVoiceAction):
            return mode == "idle"
        case #selector(pauseAction):
            return mode == "recording" || mode == "voicing"
        case #selector(resumeAction):
            return mode == "paused_recording" || mode == "paused_voice"
        case #selector(stopAction):
            return mode != "idle"
        default:
            return true
        }
    }

    func setupHUD() {
        hud.onRecord = { [weak self] in self?.startRecord() }
        hud.onShot = { [weak self] in self?.singleShot() }
        hud.onMic = { [weak self] in self?.startVoice() }
        hud.onPause = { [weak self] in self?.pauseActive() }
        hud.onResume = { [weak self] in self?.resumeActive() }
        hud.onStop = { [weak self] in self?.stopActive() }
        hud.onFolder = { [weak self] in self?.showLibrary() }
        hud.onHide = { [weak self] in self?.hud.panel.orderOut(nil) }
        screen.onCount = { [weak self] n in self?.hud.setState("recording", count: "\(n)") }
        screen.onDone = { [weak self] msg in self?.mode = "idle"; self?.hud.setState("idle"); self?.status.button?.toolTip = msg }
        voice.onTick = { [weak self] s in self?.hud.setState("voicing", count: String(format: "%d:%02d", s/60, s%60)) }
        voice.onDone = { [weak self] msg in self?.mode = "idle"; self?.hud.setState("idle"); self?.status.button?.toolTip = msg }
    }

    @objc func showHUD() { hud.show() }
    @objc func showSettings() {
        if settings == nil { settings = SettingsWindow(platform: platform) }
        settings?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc func showLibrary() {
        if library == nil { library = LibraryWindow() }
        library?.refresh()
        library?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc func openCorpus() { platform.openCorpus() }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func startRecordAction() { startRecord() }
    @objc func singleShotAction() { singleShot() }
    @objc func startVoiceAction() { startVoice() }
    @objc func pauseAction() { pauseActive() }
    @objc func resumeAction() { resumeActive() }
    @objc func stopAction() { stopActive() }

    func startRecord() {
        guard platform.screenGranted(), platform.accessibilityGranted() else { showSettings(); return }
        mode = "recording"
        hud.setState("recording", count: "0")
        screen.start()
    }

    func singleShot() {
        guard platform.screenGranted(), platform.accessibilityGranted() else { showSettings(); return }
        screen.single()
    }

    func startVoice() {
        platform.requestMic { [weak self] granted in
            guard let self else { return }
            guard granted else { self.showSettings(); return }
            self.mode = "voicing"
            self.hud.setState("voicing", count: "0:00")
            self.voice.start()
        }
    }

    func pauseActive() {
        if mode == "recording" {
            screen.pause()
            mode = "paused_recording"
            hud.setState("paused", count: "II")
        } else if mode == "voicing" {
            voice.pause()
            mode = "paused_voice"
            hud.setState("paused", count: "II")
        }
    }

    func resumeActive() {
        if mode == "paused_recording" {
            mode = "recording"
            hud.setState("recording", count: "")
            screen.resume()
        } else if mode == "paused_voice" {
            mode = "voicing"
            hud.setState("voicing", count: "")
            voice.resume()
        }
    }

    func stopActive() {
        if mode == "recording" || mode == "paused_recording" {
            screen.stop()
        } else if mode == "voicing" || mode == "paused_voice" {
            voice.stop()
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
