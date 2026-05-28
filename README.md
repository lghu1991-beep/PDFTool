# PDFTool

Windows 桌面 PDF 小工具：**Word 转 PDF**、**文字水印**、**合并**、**拆分**。

## 功能

| 功能 | 说明 |
|------|------|
| Word 转 PDF | 支持 `.doc` / `.docx` / `.wps` / `.rtf` 等 |
| 添加水印 | 文字水印 / **图片水印**（PNG/JPG，可调位置、大小、透明度） |
| PDF 压缩 | 轻 / 中 / 强 三档（强压缩内置图片重采样，可选 Ghostscript） |
| 合并 PDF | 多文件按顺序合并 |
| 拆分 PDF | 按页码范围或每页单独导出 |

## PDF 压缩说明

| 级别 | 方式 | 依赖 |
|------|------|------|
| 轻 | 压缩 PDF 流 | 无 |
| 中（推荐） | 流压缩 + 去重 | 无 |
| 强 | PyMuPDF 图片重采样（72dpi） | 内置；已装 Ghostscript 时优先用 `/screen` |

> 扫描件、图片很多的 PDF 建议用「强」压缩；纯文本 PDF 用「中」即可。  
> macOS 安装 Ghostscript（可选）：`brew install ghostscript`

## Word 转 PDF 依赖

打包后的 exe **不含** Office 引擎，转换需本机安装其一：

1. **LibreOffice（推荐，免费）**  
   https://www.libreoffice.org/download/  
   默认路径：`C:\Program Files\LibreOffice\program\soffice.exe`

2. **Microsoft Word（备选）**  
   仅 `.doc` / `.docx` / `.rtf`，需安装 Word。

## Windows 运行环境包（已内置）

项目内 **`runtime/`** 目录已包含 Python 3.11.9 安装包（约 25MB），拷到 Windows 后：

1. 双击 **`安装Python环境.bat`**（安装到 `runtime\python311\`，含 tkinter）
2. 双击 **`安装依赖并运行.bat`**（联网安装依赖并启动）

无需单独去 python.org 下载。

## 在 Windows 上生成 exe

### 快速开始（推荐）

1. 将整个 `PDFTool` 文件夹复制到 Windows
2. 安装 [Python 3.11](https://www.python.org/downloads/windows/)（勾选 **Add to PATH** 和 **tcl/tk**）
3. 双击 **`安装并打包.bat`**
4. 打开 **`dist\PDFTool.exe`**

或在 macOS 上先打开发布包，再拷到 Windows：

```bash
cd PDFTool
chmod +x pack-windows-release.sh
./pack-windows-release.sh
# 得到 release/PDFTool-Windows.zip，拷到 Windows 解压后双击 安装并打包.bat
```

### 命令行打包

```bat
cd PDFTool
build.bat
```

产物：`dist\PDFTool.exe`（单文件，约 50~80MB，内置 PDF 处理能力，无需再装 Python）

> **注意**：PyInstaller 无法跨平台，macOS 上不能生成 `.exe`，必须在 Windows 上打包。

### GitHub Actions 自动打包（推荐，无需 Windows）

在 **任意系统** 推代码到 GitHub 后，云端 Windows 环境自动构建 exe。

**一次性配置：**

```bash
cd /Users/huliguo/Desktop/work_space/PDFTool

# 1. 登录 GitHub（按提示操作）
gh auth login

# 2. 创建仓库、推送、触发打包
chmod +x setup-github.sh
./setup-github.sh
```

**下载 exe：**

1. 打开 GitHub 仓库 → **Actions** 页
2. 点最新的 **Build Windows EXE** 任务
3. 底部 **Artifacts** → 下载 `PDFTool-Windows.zip`
4. 解压得到 `PDFTool.exe`

**自动触发时机：**

- 每次 push 到 `main` / `master`
- 手动：Actions → Build Windows EXE → **Run workflow**
- 打 tag（如 `v1.0.0`）会额外发布到 **Releases** 页

> macOS 上不能本地交叉编译 `.exe`，用 GitHub Actions 即可自动出包。

## 开发运行（Windows / macOS 均可测 GUI 部分）

```bash
cd PDFTool
pip install -r requirements.txt
python src/main.py
```

> macOS 上 Word 转 PDF 不可用（需 Windows + LibreOffice/Word），水印/合并/拆分可正常测试。

## 技术栈

- Python 3.10+
- Tkinter（系统自带）
- pypdf + reportlab + pymupdf（PDF 处理 / 强压缩）
- LibreOffice headless（Word 转 PDF）
- PyInstaller（打包 exe）

## 许可

MIT
