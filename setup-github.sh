#!/bin/bash
# 初始化 GitHub 仓库并触发 Windows 自动打包
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

GH=""
if command -v gh >/dev/null 2>&1; then
  GH=gh
elif [ -x /tmp/gh_2.63.2_macOS_arm64/bin/gh ]; then
  GH=/tmp/gh_2.63.2_macOS_arm64/bin/gh
else
  echo "未找到 gh，请先安装 GitHub CLI："
  echo "  brew install gh   或   https://cli.github.com/"
  exit 1
fi

if ! $GH auth status >/dev/null 2>&1; then
  echo "请先登录 GitHub："
  echo "  $GH auth login"
  exit 1
fi

if [ ! -d .git ]; then
  git init -b main
fi

git add -A
if git diff --cached --quiet; then
  echo "无新改动，跳过提交"
else
  git commit -m "$(cat <<'EOF'
<<<<<<< HEAD
chore: PDFTool 初始版本，含 GitHub Actions 自动打包 Windows exe
=======
chore: QYPdfTool 初始版本，含 GitHub Actions 自动打包 Windows exe
>>>>>>> ea23488 (chore: QYPdfTool 初始版本，GitHub Actions 自动打包 Windows exe)

EOF
)"
fi

<<<<<<< HEAD
REPO_NAME="${1:-PDFTool}"
=======
REPO_NAME="${1:-QYPdfTool}"
>>>>>>> ea23488 (chore: QYPdfTool 初始版本，GitHub Actions 自动打包 Windows exe)
if ! $GH repo view "$($GH api user -q .login)/$REPO_NAME" >/dev/null 2>&1; then
  echo "创建 GitHub 仓库: $REPO_NAME"
  $GH repo create "$REPO_NAME" --public --source=. --remote=origin --push
else
  echo "推送到已有仓库: $REPO_NAME"
  git remote remove origin 2>/dev/null || true
  $GH repo set-default "$($GH api user -q .login)/$REPO_NAME" 2>/dev/null || true
  git remote add origin "git@github.com:$($GH api user -q .login)/$REPO_NAME.git" 2>/dev/null \
    || git remote add origin "https://github.com/$($GH api user -q .login)/$REPO_NAME.git"
  git push -u origin main
fi

echo ""
echo "触发 Windows 打包..."
$GH workflow run "Build Windows EXE" --ref main 2>/dev/null || true

USER="$($GH api user -q .login)"
echo ""
echo "=========================================="
echo "  已推送，Windows exe 正在云端自动构建"
echo "=========================================="
echo ""
echo "查看进度："
echo "  https://github.com/$USER/$REPO_NAME/actions"
echo ""
echo "构建完成后（约 3~5 分钟）："
<<<<<<< HEAD
echo "  Actions → 最新 Build Windows EXE → Artifacts → PDFTool-Windows"
echo "  解压得到 PDFTool.exe"
=======
echo "  Actions → 最新 Build Windows EXE → Artifacts → QYPdfTool-Windows"
echo "  解压得到 QYPdfTool.exe"
>>>>>>> ea23488 (chore: QYPdfTool 初始版本，GitHub Actions 自动打包 Windows exe)
echo ""
echo "打 tag 可自动发布 Release（exe 附在 Release 页）："
echo "  git tag v1.0.0 && git push origin v1.0.0"
