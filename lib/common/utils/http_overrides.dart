import 'dart:io';

/// 兼容 Android 4.4 过旧的系统 CA 证书库。
/// 仅对固定的上游域名放行证书链校验失败，不对其它请求全局放行。
class _HttpOverrides extends HttpOverrides {
  // Android 4.4 无法验证这些站点当前使用的证书链。
  // 这些域名只用于应用的源列表、更新检查和发布包下载。
  static const _legacyAndroidHosts = <String>{
    'raw.githubusercontent.com',
    'api.github.com',
    'github.com',
    'release-assets.githubusercontent.com',
    'objects.githubusercontent.com',
    'dns.google',
    'cloudflare-dns.com',
    'mirror.ghproxy.com',
    'node1.olelive.com',
  };

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        return _legacyAndroidHosts.contains(host.toLowerCase());
      };
  }
}

class HttpOverridesUtil {
  HttpOverridesUtil._();

  static void init() {
    HttpOverrides.global = _HttpOverrides();
  }
}
