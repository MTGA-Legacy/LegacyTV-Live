# LegacyTV Live

面向 Android 4.4 老电视和电视盒子的轻量 IPTV 播放器。

## 特性

- 支持 Android 4.4+，提供 ARM32/ARM64 通用构建
- 默认使用 [ChinaIPTV](https://github.com/hujingguang/ChinaIPTV) 的自动更新 M3U：
  `https://raw.githubusercontent.com/hujingguang/ChinaIPTV/main/cnTV_AutoUpdate.m3u8`
- 直播源同时尝试直连、ghfast 和 ghproxy.net；网络失败时优先显示本地缓存
- 针对 Android 4.4 的旧 CA 证书库，GitHub 上游请求使用固定域名兼容处理
- 支持 M3U、M3U8、TVBox 文本和自定义订阅
- 直播源失败时自动尝试同频道的备用地址
- 适配遥控器方向键、数字键和 OK 键
- Android 4.4 版本默认使用软件解码，避开老电视不稳定的 MediaCodec
- 播放器无广告、无需登录；默认不请求第三方 EPG，可在设置中填写自定义 EPG

ChinaIPTV 播放列表由上游项目定期更新，本仓库只引用远程地址，不复制频道数据。频道可用性取决于电视所在网络和上游实时状态。

## 安装

从 Releases 或 Actions artifact 下载 `LegacyTV.apk`（包含 armeabi-v7a 与 arm64-v8a），通过 U 盘、文件管理器或 ADB 安装。应用仍保留原 applicationId `com.htwmedia.htv`，方便覆盖已有 HTV 安装。

## 设置

- 「直播源 → 默认源服务」可修改或清空默认地址
- 「自定义直播源」可填写自己的 M3U/TXT 订阅
- 首次获取源需要网络；源缓存失效时应用会保留上一份可用缓存
- 应用启动后会开启局域网调试服务（默认端口 `10381`）：`/api/logs.txt` 查看日志，`/api/logs` 查看 JSON，`/api/status` 查看播放器状态；`/api/debug/*` 预留远程播放器诊断接口

## 从源码构建

需要 Flutter 3.13+ 和 Android SDK：

```bash
flutter pub get
flutter build apk --release --split-per-abi
```

## 许可证

本项目代码沿用 Apache-2.0。ChinaIPTV 是独立上游项目，使用其源时请遵守上游项目说明及各频道内容的适用规则。
