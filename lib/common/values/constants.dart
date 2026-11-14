/// 常量
class Constants {
  /// 默认源服务地址（内置源的默认取值）
  ///
  /// 壳源分离：App 自带的是一个**可替换的服务地址**，不是任何频道数据；
  /// 用户可在「设置 → 直播源 → 默认源服务」里改成自己的订阅接口，或清空表示不启用内置源
  /// （清空后只加载「自定义直播源」）。改动走 Prefs，服务端接入方不需要改代码。
  static const defaultIptvSourceApi = 'https://raw.githubusercontent.com/hujingguang/ChinaIPTV/main/cnTV_AutoUpdate.m3u8';

  /// ChinaIPTV 的请求入口：直连与两个内容镜像同时尝试。
  /// 镜像只代理同一个上游地址，不改变播放列表内容。
  static const defaultIptvSourceApis = <String>[
    defaultIptvSourceApi,
    'https://ghfast.top/https://raw.githubusercontent.com/hujingguang/ChinaIPTV/main/cnTV_AutoUpdate.m3u8',
    'https://ghproxy.net/https://raw.githubusercontent.com/hujingguang/ChinaIPTV/main/cnTV_AutoUpdate.m3u8',
  ];

  /// 第二个内置列表：用于补充 ChinaIPTV 缺失或失效的频道地址。
  static const backupIptvSourceApi =
      'https://raw.githubusercontent.com/best-fan/iptv-sources/main/cn_all.m3u8';

  /// 备用列表同样支持直连与两个内容镜像。
  static const backupIptvSourceApis = <String>[
    backupIptvSourceApi,
    'https://ghfast.top/https://raw.githubusercontent.com/best-fan/iptv-sources/main/cn_all.m3u8',
    'https://ghproxy.net/https://raw.githubusercontent.com/best-fan/iptv-sources/main/cn_all.m3u8',
  ];

  /// 直播源缓存时间
  static const iptvSourceCacheKeepTime = 1000 * 60 * 60; // 1小时

  /// 内置源从单列表升级为 ChinaIPTV + best-fan 双列表。
  static const iptvSourceCacheVersion = 2;

  /// epg xml
  /// XMLTV 节目单。播放列表本身没有统一 EPG，所以使用独立的轻量聚合源。
  /// 该地址位于 GitHub，RequestUtil 会自动应用 Android 4.4 的直连、DoH 与镜像回退。
  static const iptvEpgXml =
      'https://raw.githubusercontent.com/peterHchina/iptv/main/EPG.xml';

  /// epg 刷新时间阈值（小时）
  static const epgRefreshTimeThreshold = 6; // 不到6点不刷新

  /// github API 获取最新 release
  static const githubReleaseApi = 'https://api.github.com/repos/MTGA-Legacy/LegacyTV-Live/releases/latest';

  /// github代理加速地址
  static const githubProxy = 'https://ghfast.top/';

  /// github release latest (fallback HTML 页面)
  static const githubReleaseLatest = 'https://github.com/MTGA-Legacy/LegacyTV-Live/releases/latest';

  /// 设置服务器端口
  static const httpServerPort = 10381;

  /// http请求重试次数
  static const httpRetryCount = 10;

  /// HTTP请求重试间隔时间（毫秒）
  static const httpRetryInterval = 3000;
}
