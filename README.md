# webview_flutter_jsbridge

A flutter jsbridge package compatible with [webview_flutter](https://github.com/flutter/plugins/tree/master/packages/webview_flutter/webview_flutter) 4.0.0, dependent on inject javascript.

This package is based on [webview_jsbridge](https://github.com/KouYiGuo/webview_jsbridge), because of webview_jsbridge is too old that can't compatible with newest webview_flutter, so I fix and delete some code.

I'm an iOSer, so most js code and JSBridge code is based on [WebViewJavascriptBridge](https://github.com/marcuswestin/WebViewJavascriptBridge). You can see they are very similar.

I also test on Android Device, it's OK.

## Usage

```dart
class HomeView extends StatelessWidget {
  final jsBridge = JSBridge();

  @override
  Widget build(BuildContext context) {
    final controller = _webViewControllerSetting();

    return Scaffold(
      appBar: AppBar(
        title: Text("Flutter WebView JSBridge"),
        actions: [
          TextButton(
            onPressed: _callJS,
            child: Text(
              "callJS",
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
    jsBridge.registerHandler("testFlutterCallback", _nativeHandler);

    webController
      /// javascript enable
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            print('Page finished loading: $url');
            /// inject javascript
            jsBridge.injectJavascript();
          },
        ),
      )
      ..loadFlutterAsset("assets/example.html");

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
    return '_defaultHandler res from native';
  }
}
```

### example.html implementation

example.html

```html
<!doctype html>
<html><head>
    <meta name="viewport" content="user-scalable=no, width=device-width, initial-scale=1.0, maximum-scale=1.0">
	<style type='text/css'>
		html { font-family:Helvetica; color:#222; }
		h1 { color:steelblue; font-size:24px; margin-top:24px; }
		button { margin:0 3px 10px; font-size:12px; }
		.logLine { border-bottom:1px solid #ccc; padding:4px 2px; font-family:courier; font-size:11px; }
	</style>
</head><body>
	<h1>WebViewJavascriptBridge Demo</h1>
	<script>
	window.onerror = function(err) {
		log('window.onerror: ' + err)
	}

    function setupWebViewJavascriptBridge(callback) {
        if (window.WebViewJavascriptBridge) { return callback(WebViewJavascriptBridge); }
        if (window.WVJBCallbacks) { return window.WVJBCallbacks.push(callback); }
        window.WVJBCallbacks = [callback];
        var WVJBIframe = document.createElement('iframe');
        WVJBIframe.style.display = 'none';
        WVJBIframe.src = 'https://__bridge_loaded__';
        document.documentElement.appendChild(WVJBIframe);
        setTimeout(function() { document.documentElement.removeChild(WVJBIframe) }, 0)
    }

    setupWebViewJavascriptBridge(function(bridge) {
		var uniqueId = 1
		function log(message, data) {
			var log = document.getElementById('log')
			var el = document.createElement('div')
			el.className = 'logLine'
			el.innerHTML = uniqueId++ + '. ' + message + ':<br/>' + JSON.stringify(data)
			if (log.children.length) { log.insertBefore(el, log.children[0]) }
			else { log.appendChild(el) }
		}

		bridge.registerHandler('testJavascriptHandler', function(data, responseCallback) {
			log('Flutter called testJavascriptHandler with', data)
			var responseData = { 'Javascript Says':'Right back atcha!' }
			log('JS responding with', responseData)
			responseCallback(responseData)
		})

		document.body.appendChild(document.createElement('br'))

		var callbackButton = document.getElementById('buttons').appendChild(document.createElement('button'))
		callbackButton.innerHTML = 'Fire testFlutterCallback'
		callbackButton.onclick = function(e) {
			e.preventDefault()
			log('JS calling handler "testFlutterCallback"')
			bridge.callHandler('testFlutterCallback', {'foo': 'bar'}, function(response) {
				log('JS got response', response)
			})
		}
	})
	</script>
	<div id='buttons'></div> <div id='log'></div>
</body></html>

```
