import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:video_player_example/common/index.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

final _logger = LoggerUtil.create(['http_server']);

class HttpServerUtil {
  HttpServerUtil._();

  static var _isInitialized = false;
  static Future<void>? _initializing;

  static String serverUrl = 'http://0.0.0.0:${Constants.httpServerPort}';

  static Future<void> init() async {
    if (_isInitialized) return;
    final pending = _initializing;
    if (pending != null) return pending;

    final future = _start();
    _initializing = future;
    try {
      await future;
    } finally {
      if (identical(_initializing, future)) _initializing = null;
    }
  }

  static Future<void> _start() async {

    var app = Router();

    app.get('/', (request) async {
      try {
        return shelf.Response.ok(
          await rootBundle.loadString('assets/web/index.html'),
          headers: {'content-type': 'text/html'},
        );
      } catch (e) {
        _logger.error('加载index.html失败: $e');
        return shelf.Response.internalServerError(body: '加载页面失败: $e');
      }
    });

    app.get('/api/IptvSettings/customIptvSource', (request) async {
      var source = request.url.queryParameters['source'] ?? '';

      _logger.debug('设置自定义直播源: $source');
      IptvSettings.customIptvSource = source;
      IptvSettings.iptvSourceSimplify = false;
      IptvSettings.iptvSourceCacheTime = 0;
      IptvSettings.epgCacheHash = 0;

      return shelf.Response.ok('success');
    });

    app.get('/api/logs', (request) {
      final limit = int.tryParse(request.url.queryParameters['limit'] ?? '') ?? 200;
      return _jsonResponse(<String, dynamic>{
        'count': LoggerUtil.history(limit: limit).length,
        'logs': LoggerUtil.history(limit: limit),
      });
    });

    app.get('/api/logs.txt', (request) {
      final limit = int.tryParse(request.url.queryParameters['limit'] ?? '') ?? 200;
      return shelf.Response.ok(
        LoggerUtil.historyLines(limit: limit).join('\n'),
        headers: {
          'content-type': 'text/plain; charset=utf-8',
          'cache-control': 'no-store',
        },
      );
    });

    app.post('/api/logs/clear', (request) {
      LoggerUtil.clearHistory();
      return _jsonResponse(<String, dynamic>{'ok': true});
    });

    app.get('/api/status', (request) {
      final player = GetIt.I<PlayerStore>();
      final iptv = GetIt.I<IptvStore>();
      return _jsonResponse(<String, dynamic>{
        'app': 'LegacyTV Live',
        'decoder': player.decoderMode,
        'hardwareDecodeEnabled': player.hardwareDecodeEnabled,
        'hardwareDecodeFallback': player.hardwareDecodeFallback,
        'playerState': player.state.name,
        'nativeState': player.player.state.toString().split('.').last,
        'resolution': {
          'width': player.resolution.width,
          'height': player.resolution.height,
        },
        'aspectRatio': player.aspectRatio,
        'channel': iptv.currentIptv.name,
        'serverUrl': serverUrl,
      });
    });

    var handler = const shelf.Pipeline().addMiddleware(shelf.logRequests()).addHandler(app.call);

    var server = await io.serve(handler, InternetAddress.anyIPv4, Constants.httpServerPort);

    _isInitialized = true;
    serverUrl = 'http://${await _getLocalIPV4()}:${server.port}';
    _logger.debug('启动 $serverUrl');
  }

  static shelf.Response _jsonResponse(Object body) {
    return shelf.Response.ok(
      jsonEncode(body),
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'cache-control': 'no-store',
      },
    );
  }

  static Future<String> _getLocalIPV4() async {
    for (var interface in await NetworkInterface.list()) {
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4) {
          return addr.address;
        }
      }
    }

    return '0.0.0.0';
  }
}
