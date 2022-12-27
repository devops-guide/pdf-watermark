# pdf-watermark

<img src="https://github.com/devops-guide/pdf-watermark/blob/master/icons/logo.png?raw=true" width="128"/>
用于给 PDF 添加水印

平铺效果：

![平铺效果](https://tva1.sinaimg.cn/large/008vxvgGly1h7r7dt67p8j31hf0u00x9.jpg)

居中效果：

![居中效果](https://tva1.sinaimg.cn/large/008vxvgGly1h7r7einzkvj31he0u076e.jpg)

界面：

![界面](https://tva1.sinaimg.cn/large/008vxvgGly1h7r7f6zvawj318g0rswgh.jpg)

在 [Releases](https://github.com/devops-guide/pdf-watermark/releases) 中下载最新版本。

# Mac 无法正常打开

因为“穷”，所以没有开发者账号进行签名。点击【取消】。

![无法打开](https://tva1.sinaimg.cn/large/008vxvgGly1h9ipnjmcg6j30eg0dsjru.jpg)

进入系统偏好设置，点击【安全性与隐私】，如图

![安全性与隐私](https://tva1.sinaimg.cn/large/008vxvgGly1h9ipqjg25jj30za0u0whr.jpg)

![仍要打开](https://tva1.sinaimg.cn/large/008vxvgGly1h9ippjjerij30y50u0wgn.jpg)

选择【仍要打开】。

![打开](https://tva1.sinaimg.cn/large/008vxvgGly1h9ipsg598vj30eg0kk0tn.jpg)

打开即可正常使用。

# 开发

打包成pkg

```
$ git clone git@github.com:devops-guide/pdf-watermark.git
$ cd pdf-watermark
$ npm install
$ npm run package
```

如果打包失败了，提示Node JS版本Node.js >= 14.17.5，使用NVM安装

```
$ nvm use
```