# 工具集 macOS 原生版 (Objective-C)

使用 **AppKit (Objective-C)** 作为壳：**入口页** 选择工具；**PDF 工具** 由 Python 引擎处理；**音频编辑** 界面已就绪（功能逐步接入）。

## 运行

```bash
chmod +x build-native-mac.sh run-native-mac.sh
./build-native-mac.sh
open dist/PDFToolNative.app
```

## 开发调试

```bash
./run-native-mac.sh
```

使用本机 `python3` + `src/engine_cli.py`，无需每次打包引擎。

## 源码位置

| 组件 | 路径 |
|------|------|
| 入口页 | `QYPTHubWindowController` |
| PDF 工具 | `QYPTMainWindowController` + `src/engine_cli.py` |
| 音频编辑 | `QYPTAudioEditWindowController` + `QYPTFFmpegAudio`（ffmpeg） |
| 应用包 | `dist/PDFToolNative.app` |

## 要求

- macOS 11+
- Xcode Command Line Tools（`clang`）
- Python 3 + `requirements.txt`
- Word 转 PDF：安装 [LibreOffice](https://www.libreoffice.org/)
- 音频编辑：**打包时已内置 ffmpeg**（构建机需先 `brew install ffmpeg`）；`./run-native-mac.sh` 开发模式仍用本机 ffmpeg

## 与旧版

- `dist/PDFTool.app`：Tkinter 打包，易出现空白窗口
- **`dist/PDFToolNative.app`**：请使用此原生版
