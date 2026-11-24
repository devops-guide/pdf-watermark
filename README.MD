# PDF 水印 (PDF Watermark)

<p align="center">
  <img src="icons/logo.png" width="128" alt="PDF Watermark Logo">
</p>

<p align="center">
  一款为 macOS 桌面打造的原生 PDF 水印应用。完全离线运行，极致轻快，杜绝隐私泄露。
</p>

<p align="center">
  <a href="https://github.com/devops-guide/pdf-watermark/releases"><img src="https://img.shields.io/github/v/release/devops-guide/pdf-watermark?color=4177F6&label=Release" alt="Latest Release"></a>
  <img src="https://img.shields.io/badge/Platform-macOS%20(Apple%20Silicon)-brightgreen" alt="Platform">
  <img src="https://img.shields.io/badge/Language-Pure%20MoonBit-blue" alt="Pure MoonBit">
  <img src="https://img.shields.io/badge/Framework-Proton%200.9.1-orange" alt="Proton">
</p>

---

## 桌面端产品特点

- 🔒 **100% 本地离线处理，杜绝隐私外泄**  
  所有 PDF 文件流均直接在本地原生处理，不依赖网络、不上传任何云端服务器，保障商业合同、财务报表、个人证件等机密文档安全无忧。
- 📝 **文字与图片印章双模式**  
  - **文字水印**：支持多行文字、平铺（全页平铺网格）与居中水印，支持智能字号缩放、平铺旋转角度、网格间距与不透明度调节。
  - **图片 / 印章水印**：支持 PNG 透明印章或签名图片，支持居中印章或全页平铺，缩放比例与透明度随心调节。
- 📄 **灵活细粒度的页码控制**  
  - 支持全部页面加水印；
  - 预设一键“**跳过封面**”（从第 2 页开始加水印）；
  - 支持自定义页码范围表达式（如 `1-5, 8`）。
- 🛡️ **安全原子保存与源文件保护**  
  保存时默认在源文件同级目录生成 `原文件名-watermark.pdf`，采用先写入临时文件、验证通过后再原子替换的机制，绝不误改或损坏源文件。
- ⚡ **原生极速体验**  
  核心引擎由纯 MoonBit 原生编译为本地机器码，告别 Electron 庞大臃肿的运行时开销，启停迅速、内存占用极低。

---

## 产品界面与效果

### 桌面端界面

![产品主界面](https://tva1.sinaimg.cn/large/008vxvgGly1h7r7f6zvawj318g0rswgh.jpg)

### 平铺水印效果

![平铺效果](https://tva1.sinaimg.cn/large/008vxvgGly1h7r7dt67p8j31hf0u00x9.jpg)

### 居中水印效果

![居中效果](https://tva1.sinaimg.cn/large/008vxvgGly1h7r7einzkvj31he0u076e.jpg)

---

## 下载与使用

前往 [Releases 页面](https://github.com/devops-guide/pdf-watermark/releases) 下载最新的 macOS 版本安装包：

1. 下载 `PDF.Watermark.app.zip` 并解压。
2. 将 `PDF Watermark.app` 拖入 `Applications`（应用程序）文件夹。
3. 双击打开，将需要加水印的 PDF 文件直接拖拽到窗口中，设置水印参数后点击“生成并保存”即可。

---

## macOS 首次打开指引

因为没有购买苹果商业开发者证书对安装包进行公证签名，macOS 首次打开未签名的应用时会弹出如下拦截提示：

![无法打开](https://tva1.sinaimg.cn/large/008vxvgGly1h9ipnjmcg6j30eg0dsjru.jpg)

请按照以下步骤允许运行（仅需在首次打开时操作一次）：

1. 点击提示框上的【取消】或【好】。
2. 打开 Mac 的【系统设置】（或旧版 macOS 的【系统偏好设置】）→【隐私与安全性】。
3. 滚动到页面下方的【安全性】一栏，会看到“已阻止使用 PDF Watermark”的提示：

![安全性与隐私](https://tva1.sinaimg.cn/large/008vxvgGly1h9ipqjg25jj30za0u0whr.jpg)

4. 点击【仍要打开】：

![仍要打开](https://tva1.sinaimg.cn/large/008vxvgGly1h9ippjjerij30y50u0wgn.jpg)

5. 在最后弹出的安全确认提示框中点击【打开】即可正常进入应用。

![打开](https://tva1.sinaimg.cn/large/008vxvgGly1h9ipsg598vj30eg0kk0tn.jpg)

---

## 开发者与源码构建

本项目为 100% 纯 MoonBit + Proton 桌面工程，**无需 Node.js 与 npm 环境**。

### 环境准备

安装 [MoonBit 工具链](https://www.moonbitlang.com/)：

```sh
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
export PATH="$HOME/.moon/bin:$PATH"
```

安装并初始化 Proton CLI：

```sh
./scripts/install-proton.sh
```

### 常用命令

| 命令 | 用途 |
| --- | --- |
| `proton_cli dev` | 启动桌面应用开发预览 |
| `moon test --target native` | 运行原生测试套件 |
| `moon fmt` / `moon check --target native` | 代码格式化与静态检查 |
| `proton_cli package --release` | 构建并打包 macOS 原生应用（输出至 `dist/`） |

### 命令行 CLI 使用

编译出的本地二进制亦可直接作为命令行工具自动化处理：

```sh
# 命令行快速加水印
_build/native/release/build/app/app.exe 计划书.pdf "CONFIDENTIAL"

# 查看命令行完整参数帮助
_build/native/release/build/app/app.exe --help
```
