# 工具集 Windows 版

与 macOS 原生版相同的产品结构：**入口页** → **PDF 工具** / **音频编辑**。

## 运行

```bat
安装并打包.bat
dist\PDFTool.exe
```

或开发：

```bat
python src\main.py
```

## 打包说明

- `build.bat` 会先执行 `scripts\prepare_ffmpeg_win.py`，将本机 `ffmpeg` 所在 **bin 目录** 复制到 `vendor\ffmpeg-win`，再打入 exe。
- 构建机需已安装 ffmpeg 并加入 PATH（推荐 [gyan.dev builds](https://www.gyan.dev/ffmpeg/builds/) essentials 包）。
- 打包后用户机器 **无需再装 ffmpeg**。

## 模块

| 模块 | 文件 |
|------|------|
| 入口 | `hub_app.py` |
| PDF | `pdf_app.py` |
| 音频 | `audio_app.py` + `ffmpeg_audio.py` |
