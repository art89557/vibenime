import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../data/auth_repository.dart';

/// In-app WebView untuk login OAuth ke AniList.
///
/// Dipakai sebagai pengganti `flutter_web_auth_2` yang custom-tab-nya kadang
/// tidak balik ke app setelah login. Dengan WebView, semua flow tetap di
/// dalam app — popup login style yang lebih reliable.
///
/// Pop dengan `String token` jika sukses, atau `null` kalau user back.
class AuthWebViewScreen extends ConsumerStatefulWidget {
  const AuthWebViewScreen({super.key});

  @override
  ConsumerState<AuthWebViewScreen> createState() => _AuthWebViewScreenState();
}

class _AuthWebViewScreenState extends ConsumerState<AuthWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _alreadyPopped = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    final repo = ref.read(authRepositoryProvider);
    final authUrl = repo.buildAuthorizeUrl();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.surfaceDark)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            final token = repo.extractTokenFromCallback(request.url);
            if (token != null && !_alreadyPopped) {
              _alreadyPopped = true;
              Navigator.of(context).pop(token);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(authUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login AniList'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (!_alreadyPopped) {
              _alreadyPopped = true;
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const LinearProgressIndicator(
              backgroundColor: Colors.transparent,
            ),
        ],
      ),
    );
  }
}
