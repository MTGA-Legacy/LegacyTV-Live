import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:video_player_example/common/index.dart';

import '../../../common/widgets/two_dimension_list_view.dart';

class SettingGroup {
  final String name;
  final List<SettingItem> items;

  SettingGroup({required this.name, required this.items});
}

class SettingItem {
  final String title;
  final String Function() value;
  final String Function() description;
  final void Function() onTap;
  final void Function()? onLongTap;

  SettingItem({
    required this.title,
    required this.value,
    required this.description,
    required this.onTap,
    this.onLongTap,
  });
}

class SettingsMain extends StatefulWidget {
  const SettingsMain({super.key});

  @override
  State<SettingsMain> createState() => _SettingsMainState();
}

class _SettingsMainState extends State<SettingsMain> {
  final iptvStore = GetIt.I<IptvStore>();
  final playerStore = GetIt.I<PlayerStore>();

  late final List<SettingItem> _settingItemList;

  String _formatDuration(int ms) {
    if (ms < 60000) {
      return '${ms ~/ 1000}秒';
    } else if (ms < 3600000) {
      return '${ms ~/ 60000}分钟';
    } else {
      return '${ms ~/ 3600000}小时';
    }
  }

  String _formatCacheAge(int timestamp) {
    if (timestamp <= 0) return '无缓存';
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    if (age < 60000) return '刚刚缓存';
    if (age < 3600000) return '${age ~/ 60000}分钟前缓存';
    return '${age ~/ 3600000}小时前缓存';
  }

  int _sourceCacheTime() {
    final builtin = IptvSettings.iptvSourceCacheTime;
    final custom = IptvSettings.customIptvSourceCacheTime;
    return builtin > custom ? builtin : custom;
  }

  String _sourceStatus() {
    switch (iptvStore.listStatus.value) {
      case IptvListStatus.loading:
        return '加载中';
      case IptvListStatus.ready:
        return '${iptvStore.iptvList.length} 个频道';
      case IptvListStatus.failed:
        return '加载失败';
    }
  }

  String _sourceStatusDescription() {
    final cached = _sourceCacheTime();
    switch (iptvStore.listStatus.value) {
      case IptvListStatus.loading:
        return cached > 0 ? '正在更新，先使用 ${_formatCacheAge(cached)}' : '正在请求直播源';
      case IptvListStatus.ready:
        return cached > 0 ? '${_formatCacheAge(cached)}，点击刷新' : '已从网络获取，点击刷新';
      case IptvListStatus.failed:
        return cached > 0 ? '网络失败，仍可使用 ${_formatCacheAge(cached)}' : '没有可用直播源，点击重试';
    }
  }

  String _serverEndpoint() {
    final uri = Uri.tryParse(HttpServerUtil.serverUrl);
    if (uri == null || uri.port == 0) return ':${Constants.httpServerPort}';
    if (uri.host == '0.0.0.0') return ':${uri.port}';
    return '${uri.host}:${uri.port}';
  }

  /// 电视端文本编辑弹窗
  ///
  /// Flutter 的按键分发顺序是「叶子节点 → 根」(focus_manager.dart:1995)，
  /// 而 EditableText 在最内层就把上下方向键映射成了光标移动
  /// (editable_text.dart:4835)。输入框一旦拿到焦点，外层 Focus 便再也收不到方向键，
  /// 「保存」按钮因此不可达；电视端又没有输入法，onSubmitted 同样不会触发。
  /// 所以改由容器层统一托管按键：方向键在各元素间移动焦点，OK 键执行当前元素。
  /// 具体实现对所有文本文件复用同一份，见 TvTextEditDialog。
  void _showTvTextEditDialog({
    required String title,
    required String hint,
    required String initialValue,
    required ValueChanged<String> onSave,
    String? subtitle,
    List<TvDialogButton> extraButtons = const <TvDialogButton>[],
    double maxWidth = 500,
    double fontSize = 24,
  }) {
    showDialog(
      context: context,
      builder: (_) => TvTextEditDialog(
        title: title,
        subtitle: subtitle,
        hint: hint,
        initialValue: initialValue,
        onSave: onSave,
        extraButtons: extraButtons,
        maxWidth: maxWidth,
        fontSize: fontSize,
      ),
    );
  }

  void _showChannelSelectDialog() async {
    final allChannels = await IptvUtil.getAllChannelNames();
    if (!mounted) return;
    if (allChannels.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('无可选频道，请先获取直播源')));
      return;
    }

    final initialSelected = Set<String>.from(IptvSettings.allowedChannels.isNotEmpty
        ? IptvSettings.allowedChannels
        : allChannels.where((n) => n.toLowerCase().startsWith('cctv') || n.endsWith('卫视')));

    final result = await ChannelSelectDialog.show(
      context,
      allChannels: allChannels,
      selected: initialSelected,
    );

    if (result != null && mounted) {
      IptvSettings.allowedChannels = result.toList();
      IptvSettings.iptvSourceSimplify = true;
      IptvSettings.epgCacheHash = 0;
      iptvStore.refreshIptvList().then((_) { if (mounted) setState(() {}); });
    }
  }

  void _showCustomSourceDialog() {
    _showTvTextEditDialog(
      title: '自定义直播源',
      subtitle: '支持 m3u 订阅链接与 TVBox 链接，也可用手机扫码后在网页填写',
      hint: '输入订阅链接',
      initialValue: IptvSettings.customIptvSource,
      maxWidth: 700,
      fontSize: 24,
      extraButtons: [
        TvDialogButton(label: '二维码', onPressed: _showServerQrcode),
      ],
      onSave: (value) {
        IptvSettings.customIptvSource = value.trim();
        IptvSettings.iptvSourceSimplify = false;
        IptvSettings.iptvSourceCacheTime = 0;
        IptvSettings.epgCacheHash = 0;
        iptvStore.refreshIptvList().then((_) { if (mounted) setState(() {}); });
      },
    );
  }

  /// 默认源服务地址
  ///
  /// 壳源分离的关键入口：把写死的服务端地址变成可配置项。
  /// 留空 = 停用内置源，App 退化为纯播放器，只加载用户自己的订阅。
  void _showDefaultApiDialog() {
    _showTvTextEditDialog(
      title: '默认源服务',
      subtitle: '默认使用 ChinaIPTV 自动更新源；留空表示只加载自定义订阅',
      hint: '输入接口地址',
      initialValue: IptvSettings.defaultIptvSourceApi,
      maxWidth: 700,
      fontSize: 20,
      onSave: (value) {
        IptvSettings.defaultIptvSourceApi = value.trim();
        IptvSettings.epgCacheHash = 0;
        iptvStore.refreshIptvList().then((_) { if (mounted) setState(() {}); });
      },
    );
  }

  void _showServerQrcode() {
    final fg = AppTheme.fg(context);
    NavigatorUtil.push(
      context,
      TvModalScaffold(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '扫描二维码设置',
                style: AppTheme.text(fg, 36.sp),
              ),
              SizedBox(height: 12.h),
              Text(
                HttpServerUtil.serverUrl,
                style: AppTheme.text(AppTheme.fgFaded(context, 0.7), 24.sp),
              ),
              SizedBox(height: 24.h),
              Container(
                decoration: BoxDecoration(
                  color: fg,
                  borderRadius: BorderRadius.circular(20).r,
                ),
                padding: const EdgeInsets.all(8),
                child: SizedBox(
                  height: 300.h,
                  width: 300.h,
                  child: PrettyQrView.data(
                    data: HttpServerUtil.serverUrl,
                    decoration: PrettyQrDecoration(
                      shape: PrettyQrSmoothSymbol(
                        color: AppTheme.bg(context),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                '点击空白处或按 ESC 返回',
                style: AppTheme.text(AppTheme.fgFaded(context, 0.5), 20.sp),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 社区与反馈：展示 QQ 群二维码
  ///
  /// 用内置图片资产而不是 qm.qq.com 的加群链接再生成二维码——
  /// 那种链接带时效 key，会过期；官方生成的群二维码图最稳。
  void _showCommunityQrcode() {
    final fg = AppTheme.fg(context);
    NavigatorUtil.push(
      context,
      TvModalScaffold(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '扫码加入交流群',
                style: AppTheme.text(fg, 36.sp),
              ),
              SizedBox(height: 12.h),
              Text(
                '频道失效、问题反馈、交流用法（任选其一，一群人满请进二群）',
                style: AppTheme.text(AppTheme.fgFaded(context, 0.7), 24.sp),
              ),
              SizedBox(height: 24.h),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _groupQrCard('assets/images/qq-group1.jpg', '一群 2166024531'),
                  SizedBox(width: 48.w),
                  _groupQrCard('assets/images/qq-group2.jpg', '二群 1067526818'),
                ],
              ),
              SizedBox(height: 24.h),
              Text(
                '点击空白处或按 ESC 返回',
                style: AppTheme.text(AppTheme.fgFaded(context, 0.5), 20.sp),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupQrCard(String asset, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16).r,
          child: Image.asset(
            asset,
            height: 340.h,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          label,
          style: AppTheme.text(AppTheme.fg(context), 26.sp),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    refreshSettingGroupList();

    // 同样要判 mounted：init 是异步的，用户可能在服务起来前就退出了设置页
    HttpServerUtil.init().then((_) { if (mounted) setState(() {}); });
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) => SizedBox(
        height: 190.w + 20.h,
        child: TwoDimensionListView(
          size: (rowHeight: 190.w, colWidth: 400.w),
          scrollOffset: (row: 0, col: -1),
          gap: (row: 20.h, col: 20.w),
          itemCount: (
            row: 1,
            col: (_) => _settingItemList.length,
          ),
          onSelect: (position) => setState(() {
            _settingItemList.elementAtOrNull(position.col)?.onTap();
          }),
          onLongSelect: (position) => setState(() {
            _settingItemList.elementAtOrNull(position.col)?.onLongTap?.call();
          }),
          itemBuilder: (context, position, isSelected) {
            final item = _settingItemList[position.col];

            return _buildSettingItem(item, isSelected);
          },
        ),
      ),
    );
  }

  Widget _buildSettingItem(SettingItem item, bool isSelected) {
    final textColor = AppTheme.tileText(context, isSelected);

    return Container(
      padding: const EdgeInsets.all(30).r,
      decoration: BoxDecoration(
        // 只使用半透明色块制造基础磨砂感，不叠加模糊、渐变或阴影。
        color: AppTheme.tileFill(context, isSelected),
        borderRadius: BorderRadius.circular(20).r,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.title,
                style: AppTheme.text(textColor, 30.sp),
              ),
              Text(
                item.value(),
                style: AppTheme.text(textColor, 30.sp),
              ),
            ],
          ),
          Text(
            item.description(),
            style: AppTheme.text(textColor, 24.sp),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          )
        ],
      ),
    );
  }

  void refreshSettingGroupList() {
    final groupList = [
      SettingGroup(name: '运行状态', items: [
        SettingItem(
          title: '解码模式',
          value: () => playerStore.decoderMode == 'software' ? '软件解码' : '硬件解码',
          description: () => playerStore.decoderMode == 'software'
              ? 'Android 4.4 固定使用 FFmpeg，兼容老电视'
              : '当前使用 MediaCodec',
          onTap: () => _showProbeResult(
            '播放器',
            playerStore.decoderMode == 'software'
                ? '当前固定使用软件解码，避免厂商 MediaCodec 兼容问题'
                : '当前使用硬件解码',
          ),
        ),
        SettingItem(
          title: '直播源状态',
          value: _sourceStatus,
          description: _sourceStatusDescription,
          onTap: () {
            iptvStore.refreshIptvList().then((_) {
              if (mounted) setState(() {});
            });
          },
        ),
        SettingItem(
          title: '网络策略',
          value: () => '三路并发',
          description: () => '直连、ghfast、ghproxy.net 同时请求，成功即用',
          onTap: () => _showProbeResult(
            '直播源网络策略',
            '直连和两个内容镜像只用于获取同一份 ChinaIPTV 播放列表；失败时保留本地缓存',
          ),
        ),
      ]),
      SettingGroup(name: '应用', items: [
        SettingItem(
          title: '开机自启',
          value: () => AppSettings.bootLaunch ? '启用' : '禁用',
          description: () => '下次重启生效',
          onTap: () {
            AppSettings.bootLaunch = !AppSettings.bootLaunch;
            // 这类开关不走网络请求，没有异步回调替我们刷新，
            // 少了这句点击后界面纹丝不动，用户会以为没点上。
            setState(() {});
          },
        ),
      ]),
      SettingGroup(name: '控制', items: [
        SettingItem(
          title: '换台反转',
          value: () => IptvSettings.channelChangeFlip ? '反转' : '正常',
          description: () => IptvSettings.channelChangeFlip ? '方向键上：下一个频道\n方向键下：上一个频道' : '方向键上：上一个频道\n方向键下：下一个频道',
          onTap: () {
            IptvSettings.channelChangeFlip = !IptvSettings.channelChangeFlip;
            // 同「开机自启」：纯开关，靠手动 rebuild 让同一个 item 重新求值 value/description
            setState(() {});
          },
        ),
      ]),
      SettingGroup(name: '直播源', items: [
        SettingItem(
          title: '默认源服务',
          value: () {
            final api = IptvSettings.defaultIptvSourceApi;
            if (api.isEmpty) return '已停用';
            return api == Constants.defaultIptvSourceApi ? 'ChinaIPTV' : '自定义接口';
          },
          description: () => IptvSettings.defaultIptvSourceApi.isEmpty
              ? '当前只加载自定义源；点击重新配置，长按恢复默认'
              : 'ChinaIPTV 自动更新源；点击编辑，长按恢复默认',
          onTap: () => _showDefaultApiDialog(),
          onLongTap: () {
            IptvSettings.defaultIptvSourceApi = Constants.defaultIptvSourceApi;
            IptvSettings.epgCacheHash = 0;
            iptvStore.refreshIptvList().then((_) { if (mounted) setState(() {}); });
          },
        ),
        SettingItem(
          title: '直播源精简',
          value: () {
            if (!IptvSettings.iptvSourceSimplify) return '禁用';
            final count = IptvSettings.allowedChannels.length;
            return count > 0 ? '启用 ($count个频道)' : '启用';
          },
          description: () {
            if (!IptvSettings.iptvSourceSimplify) return '显示完整直播源';
            final count = IptvSettings.allowedChannels.length;
            if (count > 0) return '仅显示已选频道，点击自定义';
            return '显示精简直播源(仅央视、地方卫视)';
          },
          onTap: () {
            if (IptvSettings.iptvSourceSimplify) {
              _showChannelSelectDialog();
            } else {
              IptvSettings.iptvSourceSimplify = true;
              IptvSettings.epgCacheHash = 0;
              iptvStore.refreshIptvList().then((_) { if (mounted) setState(() {}); });
            }
          },
          onLongTap: () {
            if (!IptvSettings.iptvSourceSimplify) return;
            IptvSettings.iptvSourceSimplify = false;
            IptvSettings.epgCacheHash = 0;
            iptvStore.refreshIptvList().then((_) { if (mounted) setState(() {}); });
          },
        ),
        SettingItem(
          title: '自定义直播源',
          value: () => IptvSettings.customIptvSource.isNotEmpty ? '已启用' : '未启用',
          description: () {
            if (IptvSettings.customIptvSource.isEmpty) return '点击设置 M3U、M3U8 或 TVBox 订阅';
            return '已配置订阅；点击编辑，长按清除';
          },
          onTap: () => _showCustomSourceDialog(),
          onLongTap: () {
            IptvSettings.customIptvSource = '';
            IptvSettings.iptvSourceCacheTime = 0;
            IptvSettings.epgCacheHash = 0;
            iptvStore.refreshIptvList().then((_) { if (mounted) setState(() {}); });
          },
        ),
        SettingItem(
          title: '直播源缓存',
          value: () => _sourceCacheTime() > 0 ? '可用' : '无缓存',
          description: () => _sourceCacheTime() > 0
              ? '保留 ${_formatDuration(IptvSettings.iptvSourceCacheKeepTime)}；点击清除'
              : '网络失败时无法回退；点击重新获取',
          onTap: () {
            if (_sourceCacheTime() > 0) {
              IptvUtil.clearCache().then((_) {
                if (mounted) setState(() {});
              });
            } else {
              iptvStore.refreshIptvList().then((_) {
                if (mounted) setState(() {});
              });
            }
          },
        ),
      ]),
      SettingGroup(name: '社区与反馈', items: [
        SettingItem(
          title: 'QQ 交流群',
          value: () => '2166024531 / 1067526818',
          description: () => '频道失效反馈、交流用法；点击显示群二维码',
          onTap: () => _showCommunityQrcode(),
        ),
        SettingItem(
          title: '问题反馈',
          value: () => '',
          description: () => '也可到 GitHub Discussions 发帖（可检索、永久留档）',
          onTap: () {
            _showProbeResult(
              'GitHub Discussions',
              'github.com/MTGA-Legacy/LegacyTV-Live → Discussions\n发帖时请带上：频道名 + 现象 + 地区/网络 + App 版本',
            );
          },
        ),
      ]),
      SettingGroup(name: '调试与日志', items: [
        SettingItem(
          title: '局域网调试',
          value: _serverEndpoint,
          description: () => '状态 /api/status，日志 /api/logs.txt；点击显示二维码',
          onTap: () => _showServerQrcode(),
        ),
      ]),
    ];

    _settingItemList = groupList.expand((element) => element.items).toList();
  }

  void _showProbeResult(String title, String detail) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('$title\n$detail'),
        duration: const Duration(seconds: 6),
      ));
  }
}
