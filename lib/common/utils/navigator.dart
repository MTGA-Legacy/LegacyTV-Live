import 'package:flutter/material.dart';

/// 路由工具
class NavigatorUtil {
  NavigatorUtil._();

  /// 覆盖弹出
  static Future<void> push(BuildContext context, Widget page) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 160),
        reverseTransitionDuration: const Duration(milliseconds: 120),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // 保留短暂的非线性淡入，不叠加模糊、缩放或弹性效果。
          return FadeTransition(
            opacity: animation.drive(
              Tween<double>(begin: 0.0, end: 1.0).chain(
                CurveTween(curve: Curves.easeOut),
              ),
            ),
            child: child,
          );
        },
        pageBuilder: (context, _, __) {
          return page;
        },
      ),
    );
  }
}
