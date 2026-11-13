import 'dart:convert';
import 'dart:io';

import 'package:video_player_example/common/index.dart';
import 'package:retry/retry.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as io;

final _logger = LoggerUtil.create(['请求']);

/// 网络请求工具
class RequestUtil {
  static late final RetryOptions _r;
  static final Map<String, String> _headers = {};

  /// 只对 GitHub 相关请求启用额外的解析和回退路径。
  static const _githubHosts = <String>{
    'raw.githubusercontent.com',
    'api.github.com',
    'github.com',
    'release-assets.githubusercontent.com',
    'objects.githubusercontent.com',
  };

  static const _dohResolvers = <String>[
    'https://dns.google/resolve',
    'https://cloudflare-dns.com/dns-query',
  ];

  static void addOrUpdateHeader(String key, String value) {
    _headers[key] = value;
  }

  static void removeHeader(String key) {
    _headers.remove(key);
  }

  static void init() {
    HttpOverridesUtil.init();

    _r = const RetryOptions(
      maxAttempts: 2,
      delayFactor: Duration(seconds: 2),
      maxDelay: Duration(seconds: 4),
    );
  }

  static Future<String> get(String url,
      {Duration timeout = const Duration(seconds: 15)}) async {
    if (_isGithubUrl(url)) {
      return _getGithub(url, timeout: timeout);
    }
    return _getDirect(url, timeout: timeout);
  }

  /// 普通请求只走系统网络；GitHub 请求额外尝试 DoH 解析和镜像。
  static Future<String> _getDirect(String url,
      {Duration timeout = const Duration(seconds: 15)}) async {
    http.Client? client;
    try {
      client = http.Client();
      final response = await _r.retry(() =>
          client!.get(Uri.parse(url), headers: _headers).timeout(timeout));

      if (response.statusCode == 200) {
        return utf8.decode(response.bodyBytes);
      }
      _logger.warning('请求失败 HTTP ${response.statusCode}: $url');
    }
    catch(ex){
      _logger.debug('请求异常 $url: $ex');
    }
    finally {
      // Future.timeout 只是让这个 Future 提前以异常收场，底层 socket 并不会跟着关。
      // 不显式 close 的话，超时的连接会一直挂在 client 的连接池里：
      // 拉源接口慢或不可达时（半开连接）这些连接不会被回收，越积越多，
      // 之后连正常的请求也发不出去，表现为"进了 App 就一直转"。
      client?.close();
    }
    return '';
  }

  static bool _isGithubUrl(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase();
    return host != null && _githubHosts.contains(host);
  }

  static Future<String> _getGithub(String url,
      {required Duration timeout}) async {
    // 第一跳保持普通 HTTPS，速度最快；Android 4.4 的证书兼容由 HttpOverrides 处理。
    final direct = await _getDirect(url, timeout: timeout);
    if (direct.isNotEmpty) return direct;

    final uri = Uri.parse(url);
    final addresses = await _resolveGithubHost(uri.host);
    for (final address in addresses) {
      final result = await _getGithubByAddress(url, address, timeout: timeout);
      if (result.isNotEmpty) return result;
    }

    // DoH/直连都失败时才走镜像，避免正常网络下引入额外延迟。
    final proxy = Constants.githubProxy;
    if (proxy.isNotEmpty) {
      _logger.debug('GitHub 直连失败，尝试镜像: $proxy');
      return _getDirect('$proxy$url', timeout: timeout);
    }
    return '';
  }

  /// 使用 DNS-over-HTTPS 解析 GitHub A 记录，只返回地址，不修改系统 DNS。
  static Future<List<InternetAddress>> _resolveGithubHost(String host) async {
    for (final resolver in _dohResolvers) {
      http.Client? client;
      try {
        final base = Uri.parse(resolver);
        final uri = base.replace(queryParameters: <String, String>{
          'name': host,
          'type': 'A',
        });
        client = http.Client();
        final response = await client.get(uri, headers: const {
          'accept': 'application/dns-json',
        }).timeout(const Duration(seconds: 5));
        if (response.statusCode != 200) continue;

        final data = jsonDecode(response.body);
        final answers = data['Answer'];
        if (answers is! List) continue;

        final result = <InternetAddress>[];
        for (final answer in answers) {
          if (answer is! Map || answer['type'] != 1) continue;
          final value = answer['data'];
          if (value is String) {
            final address = InternetAddress.tryParse(value);
            if (address != null) result.add(address);
          }
        }
        if (result.isNotEmpty) {
          _logger.debug('DoH 解析 $host 得到 ${result.length} 个地址');
          return result;
        }
      } catch (e) {
        _logger.debug('DoH 解析 $host 失败: $e');
      } finally {
        client?.close();
      }
    }
    return const <InternetAddress>[];
  }

  static Future<String> _getGithubByAddress(
      String url, InternetAddress address,
      {required Duration timeout}) async {
    final parsed = Uri.parse(url);
    final httpClient = HttpClient()
      ..findProxy = (_) => 'DIRECT'
      ..connectionTimeout = const Duration(seconds: 8)
      ..connectionFactory = (uri, proxyHost, proxyPort) {
        return Socket.startConnect(address, uri.port);
      };
    final client = io.IOClient(httpClient);
    try {
      final response = await client
          .get(parsed, headers: _headers)
          .timeout(timeout);
      if (response.statusCode == 200) {
        return utf8.decode(response.bodyBytes);
      }
      _logger.debug('GitHub DoH 地址请求 HTTP ${response.statusCode}: $url');
    } catch (e) {
      _logger.debug('GitHub DoH 地址请求失败 ${address.address}: $e');
    } finally {
      client.close();
    }
    return '';
  }

  /// 下载文件到本地，支持进度回调
  static Future<String?> download({
    required String url,
    required String savePath,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(url));
        request.headers.addAll(_headers);
        final response = await client
            .send(request)
            .timeout(const Duration(minutes: 5));

        if (response.statusCode != 200) return null;

        final file = File(savePath);
        final sink = file.openWrite();
        final contentLength = response.contentLength ?? -1;
        var received = 0;

        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (contentLength > 0 && onProgress != null) {
            onProgress(received / contentLength);
          }
        }
        await sink.close();

        return savePath;
      } finally {
        client.close();
      }
    } catch (e) {
      return null;
    }
  }
}
