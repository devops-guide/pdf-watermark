# PDF 水印 (Pure MoonBit)

原生 MoonBit 实现的 PDF 水印桌面应用与命令行工具。零 Node.js / npm 依赖。

在桌面或命令行给 PDF 添加文字水印。选择平铺或居中，调整字号和不透明度，支持设置指定页码范围（如跳过封面）。处理完全在本机完成。保存时默认在源文件旁生成 `原文件名-watermark.pdf`，原文件不会被覆盖。

- **核心引擎**：基于 `moonbitlang/pdflite` 原生实现，直接操作 PDF 内容流。
- **桌面框架**：基于 Proton 0.9.1（MoonBit Native 后端 + 零构建纯静态 Webview 前端）。
- **零环境依赖**：完全脱离 Node.js / npm，使用 MoonBit 原生构建与测试。

## 本地运行

只需要 [MoonBit](https://www.moonbitlang.com/) 和平台的 C/C++ 工具链（macOS 使用 Apple Silicon 和 Xcode 命令行工具）。

```sh
# 安装匹配版本的 Proton CLI
./scripts/install-proton.sh

# 启动桌面端开发预览
proton_cli dev
```

确保 `moon` 和 `proton_cli` 都在 `PATH` 中。首次运行会下载 Proton 的 Chromium 运行时。

## 测试与打包

```sh
# 运行原生单元测试
moon test --target native

# 代码格式化与静态检查
moon fmt
moon check --target native

# 打包当前平台的原生发布包
proton_cli package --release
```

打包生成的应用输出在 `dist/`。在 Apple Silicon Mac 上可以用 `proton_cli package --release --format app` 仅生成 `.app`，或指定 `--format zip` 生成 ZIP。

## 命令行与自动化使用

构建后的二进制可以直接作为原生 CLI 工具调用：

```sh
# 命令行快速加水印
_build/native/release/build/app/app.exe 计划书.pdf "CONFIDENTIAL"

# 查看使用帮助
_build/native/release/build/app/app.exe --help
```
