# PDF 水印

在桌面上给 PDF 的每一页添加中文或英文文字水印。选择平铺或居中，调整字号和不透明度；平铺还可调整角度和间距。文字过大时会按当前页面缩小。处理在本机完成。保存时默认在源文件旁生成 `原文件名-watermark.pdf`，原文件不会被覆盖。

桌面端使用 Proton 0.9.1。MoonBit 负责窗口、原生文件对话框和文件操作，Web Worker 使用 pdf-lib 处理 PDF。桌面端和 MCP 共用水印逻辑，打包后的桌面应用自带 Chromium 运行时。

## 本地运行

需要 Node.js 22、MoonBit 和平台的 C/C++ 工具链。macOS 使用 Apple Silicon 和 Xcode 命令行工具，其余平台参见 [Proton 环境要求](https://moonbit-community.github.io/proton/introduction/installation.html)。

```sh
npm ci
npm run setup:proton
npm start
```

确保 `moon` 和 `proton_cli` 都在 `PATH` 中。首次运行会下载 Proton 的 Chromium 运行时。MoonBit 0.10.22 对两处文件读取参数要求显式的可变视图，安装脚本遇到该错误时会从固定的 Proton 源码提交构建兼容版 CLI。

## 测试与打包

```sh
npm test
moon check --target native
npm run package
```

打包生成当前平台的应用，输出在 `dist/`。在 Apple Silicon Mac 上可以用 `npm run package -- --format app` 仅生成 `.app`，或指定 `--format zip` 生成 ZIP。macOS 本地构建默认未签名和公证。

## MCP

已发布 npm 包可继续使用原来的配置。

```json
{
  "mcpServers": {
    "pdf-watermark": {
      "command": "npx",
      "args": ["-y", "@xbl/pdf-watermark"]
    }
  }
}
```

要从当前分支运行 MCP，执行 `npm ci` 后，使用 `node` 作为命令，传入 `mcp-server.js` 的绝对路径。工具名为 `pdf`，接受 `filepath` 和 `text`，生成居中水印并返回输出路径。
