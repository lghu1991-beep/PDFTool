# PDFTool 分支说明

| 分支 | 平台 | 产物 | 说明 |
|------|------|------|------|
| **main** | Windows | `dist/PDFTool.exe` | 单文件 exe，含 `build.bat`、内置 Python 安装包等 |
| **mac** | macOS | `dist/PDFTool.app` | 应用程序包，含 `build-mac.sh` |

## 切换分支

```bash
# Windows 开发与打包
git checkout main

# macOS 开发与打包
git checkout mac
```

## 共用代码

- `src/pdf_core.py` — PDF 水印、压缩、合并、拆分（跨平台）
- `src/main.py` — Tkinter 界面、启动密码
- `src/word_convert.py` — **各分支按平台适配** LibreOffice 路径

## mac 分支差异

- Word 转 PDF：LibreOffice（`/Applications/LibreOffice.app/...` 或 `brew`）
- 打包：`PDFTool-mac.spec` → `PDFTool.app`
- 无 Windows 的 `.bat` / `runtime/python-3.11.9-amd64.exe` 依赖（脚本仍保留在仓库中便于合并）

## 合并建议

功能改动优先在 **mac** 或 **main** 一侧完成，再 cherry-pick / merge 到另一分支；  
仅平台相关文件（`build-*.sh/bat`、`*.spec`、说明文档）各分支独立维护。
