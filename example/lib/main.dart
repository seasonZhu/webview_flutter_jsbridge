import 'dart:async';

import 'package:flutter/material.dart';

import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'package:webview_flutter_jsbridge/webview_flutter_jsbridge.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeView(),
    );
  }
}

class HomeView extends StatelessWidget {
  final jsBridge = JSBridge();

  @override
  Widget build(BuildContext context) {
    final controller = _webViewControllerSetting();

    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter WebView JSBridge'),
        actions: [
          TextButton(
            onPressed: _callJS,
            child: Text(
              'callJS',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: WebViewWidget(
        controller: controller,
      ),
    );
  }

  WebViewController _webViewControllerSetting() {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController webController =
        WebViewController.fromPlatformCreationParams(params);

    jsBridge.webViewController = webController;
    jsBridge.defaultHandler = _defaultHandler;
    jsBridge.registerHandler('testFlutterCallback', _nativeHandler);

    webController
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            print('Page finished loading: $url');
            jsBridge.injectJavascript();
          },
        ),
      )
      ..loadFlutterAsset('assets/example.html');

    if (webController.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (webController.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
    return webController;
  }

  Future<void> _callJS() async {
    final res = await jsBridge.callHandler('testJavascriptHandler',
        data: '_callJS from native');
    print('_callJS response: $res');
  }

  Future<Object?> _nativeHandler(Object? data) async {
    await Future.delayed(Duration(seconds: 1), () {});
    return '_nativeHandler response from native';
  }

  Future<Object?> _defaultHandler(Object? data) async {
    await Future.delayed(Duration(seconds: 1), () {});
    return '_defaultHandler response from native';
  }
}
