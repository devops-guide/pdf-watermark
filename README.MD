# pdf-watermark

用于给 PDF 添加水印



平铺效果：

![](https://tva1.sinaimg.cn/large/008vxvgGly1h7r7dt67p8j31hf0u00x9.jpg)



居中效果：

![](https://tva1.sinaimg.cn/large/008vxvgGly1h7r7einzkvj31he0u076e.jpg)



界面：

![](https://tva1.sinaimg.cn/large/008vxvgGly1h7r7f6zvawj318g0rswgh.jpg)



# Mac 下如何使用
打包成pkg
```
$ git clone git@github.com:devops-guide/pdf-watermark.git
$ cd pdf-watermark
$ npm install
$ npm run package
```



如果打包失败了，提示Node JS版本Node.js >= 14.17.5，使用NVM安装

```
$ nvm install 14.17.5
```



然后在运行打包

```
$ npm run package
```



运行 ./pdf-watermark/out/pdf-watermark-darwin-x64 目录下的 pdf-watermark.pkg文件即可