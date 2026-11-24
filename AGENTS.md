# AGENTS.md

## 项目结构

- `app/main.mbt` 是应用入口（支持桌面 GUI 模式与直接 CLI 命令行模式）。
- `app/files.mbt` 管理原生文件对话框、文件保护与会话状态。
- `app/watermark.mbt` 原生 MoonBit 水印引擎，基于 `moonbitlang/pdflite` 直接操作 PDF 文件流。
- `app/layout.mbt` 负责强类型水印几何排版计算与页码范围解析。
- `frontend/` 零构建的轻量静态前端，直接由 Proton 加载。
- `moon.mod` 声明 MoonBit 依赖，`proton.project.json` 配置桌面应用及打包。
- `.github/workflows/publish.yml` 由 `v*` 标签触发，构建 Apple Silicon macOS 发布包（纯 MoonBit 工具链）。

## 开发命令

本项目为 100% 纯 MoonBit 项目，**无需 Node.js 与 npm 环境**。将 `moon` 和 `proton_cli` 加入 `PATH`。

| 命令 | 用途 |
| --- | --- |
| `./scripts/install-proton.sh` | 安装与项目匹配的 Proton CLI |
| `proton_cli dev` | 启动桌面端开发预览 |
| `moon fmt` / `moon check --target native` | 格式化和检查 MoonBit 代码 |
| `moon test --target native` | 运行原生测试套件 |
| `proton_cli build -- --release` | 编译本地原生可执行程序 |
| `proton_cli package --release` | 构建和打包桌面应用，安装包输出到 `dist/` |

## 修改与验证

- 水印算法与文件处理均在 `app/watermark.mbt` 和 `app/layout.mbt` 中实现。
- 修改桌面桥接时，同步检查 `app/files.mbt` 和 `frontend/app.js` 的 JSON 字段与命令契约。保留源 PDF 保护、取消后的临时文件清理，以及写入完成后再替换目标文件的原子流程。
- 验证时使用 `moon test --target native` 以及编译二进制测试真实 PDF 处理。
