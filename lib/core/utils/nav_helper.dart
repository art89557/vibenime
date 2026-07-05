import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../router/app_routes.dart';

/// Helper navigasi yang **defensive terhadap empty stack**.
///
/// **Masalah yang di-solve:**
/// `context.pop()` di go_router **silent fail** kalau stack kosong (mis. user
/// deep-link langsung ke screen non-shell, atau navigate pakai `context.go`
/// yang reset stack). Akibatnya tombol back terlihat tapi tidak respond.
///
/// **Pemakaian:**
/// ```dart
/// IconButton(
///   icon: const Icon(Icons.arrow_back),
///   onPressed: () => NavHelper.safePop(context, fallback: AppRoutes.home),
/// );
/// ```
class NavHelper {
  NavHelper._();

  /// Pop top route, atau fallback ke [fallback] (default: `/home`) kalau
  /// stack kosong.
  static void safePop(
    BuildContext context, {
    String fallback = AppRoutes.home,
  }) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(fallback);
    }
  }
}
