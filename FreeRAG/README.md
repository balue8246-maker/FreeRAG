# FreeRAG App

这是 FreeRAG 的原生 macOS app，使用 Swift/AppKit 实现。

## 职责

- 菜单栏常驻。
- 浮窗即时采集。
- 剪贴板文字和图片后台收集。
- 屏幕连续采样和单次截图。
- 本地语音 WAV 录制。
- 权限准备、登录时自动启动、原材料库浏览。
- 写入 `~/Documents/Corpus/` 的 LLM 友好语料结构。

## 构建

从仓库根目录运行：

```bash
FreeRAG/Packaging/build_native_app.sh
```

输出：

```text
dist/FreeRAG.app
```

## 目录

- `Sources/main.swift`：AppKit app 主实现。
- `Info.plist`：bundle 信息和 macOS 隐私权限说明。
- `Resources/Assets/`：当前 app icon。
- `Packaging/build_native_app.sh`：本地构建脚本。
