# PDFTool（mac 分支）

macOS 桌面 PDF 工具：**Word 转 PDF**、**文字/图片水印**、**压缩**、**合并**、**拆分**。

> Windows 版请切换分支：`git checkout main`

## 功能

| 功能 | 说明 |
|------|------|
| Word 转 PDF | 需本机安装 LibreOffice |
| 水印 | 中文文字 / 图片，多种位置与铺设模式 |
| PDF 压缩 | 轻 / 中 / 强 |
| 合并 / 拆分 | 多文件合并、按页拆分 |

## 运行（开发）

```bash
cd PDFTool
git checkout mac
pip3 install -r requirements.txt
python3 src/main.py
```

或：

```bash
chmod +x run-mac.sh
./run-mac.sh
```

启动密码：`18RnPiodb.`

## 打包 macOS 应用

```bash
chmod +x build-mac.sh
./build-mac.sh
```

产物：**`dist/PDFTool.app`**（双击或 `open dist/PDFTool.app`）

## Word 转 PDF（macOS）

安装 LibreOffice 任选其一：

- https://www.libreoffice.org/download/
- `brew install --cask libreoffice`

验证：

```bash
soffice --version
```

## 强压缩（可选）

```bash
brew install ghostscript
```

## GitHub Actions

推送到 **`mac`** 分支会自动构建，在 Actions 下载 **PDFTool-macOS**  artifact（`.app` 目录）。

## 分支说明

见 [BRANCHES.md](BRANCHES.md)

## 许可

MIT
