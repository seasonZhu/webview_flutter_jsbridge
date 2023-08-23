library webview_flutter_jsbridge;

import 'dart:async';
import 'dart:convert';

import 'package:webview_flutter/webview_flutter.dart';

typedef Future<T?> JSBridgeHandler<T extends Object?>(Object? data);

class JSBridge {
  late WebViewController _controller;

  set webViewController(WebViewController controller) {
    this._controller = controller;
    this._controller.addJavaScriptChannel(this._javaScriptChannel,
        onMessageReceived: this._onMessageReceived);
  }

  WebViewController get webViewController => _controller;

  JSBridgeHandler? defaultHandler;

  final _javaScriptChannel = 'WebviewFlutterJSBridgeChannel';

  final _completers = <int, Completer>{};

  var _completerIndex = 0;

  final _handlers = <String, JSBridgeHandler>{};

  Future<void> injectJavascript() async {
    final result =
        await webViewController.runJavaScriptReturningResult(injectJavaScript);
    print(result);
  }

  void registerHandler(String handlerName, JSBridgeHandler handler) {
    _handlers[handlerName] = handler;
  }

  Future<T?> callHandler<T extends Object?>(String handlerName,
      {Object? data}) async {
    return _nativeCall<T>(handlerName: handlerName, data: data);
  }

  void removeHandler(String handlerName) {
    _handlers.remove(handlerName);
  }

  void _onMessageReceived(JavaScriptMessage message) {
    final decodeStr = Uri.decodeFull(message.message);
    final jsonData = jsonDecode(decodeStr);
    final String type = jsonData['type'];
    switch (type) {
      case 'request':
        _jsCall(jsonData);
        break;
      case 'response':
      case 'error':
        _nativeCallResponse(jsonData);
        break;
      default:
        break;
    }
  }

  Future<void> _jsCall(Map<String, dynamic> jsonData) async {
    if (jsonData.containsKey('handlerName')) {
      final String handlerName = jsonData['handlerName'];
      if (_handlers.containsKey(handlerName)) {
        final data = await _handlers[handlerName]?.call(jsonData['data']);
        _jsCallResponse(jsonData, data);
      } else {
        _jsCallError(jsonData);
      }
    } else {
      if (defaultHandler != null) {
        final data = await defaultHandler?.call(jsonData['data']);
        _jsCallResponse(jsonData, data);
      } else {
        _jsCallError(jsonData);
      }
    }
  }

  void _jsCallResponse(Map<String, dynamic> jsonData, Object? data) {
    jsonData['type'] = 'response';
    jsonData['data'] = data;
    _evaluateJavascript(jsonData);
  }

  void _jsCallError(Map<String, dynamic> jsonData) {
    jsonData['type'] = 'error';
    _evaluateJavascript(jsonData);
  }

  Future<T?> _nativeCall<T extends Object?>(
      {String? handlerName, Object? data}) async {
    final jsonData = {
      'index': _completerIndex,
      'type': 'request',
    };
    if (data != null) {
      jsonData['data'] = data;
    }
    if (handlerName != null) {
      jsonData['handlerName'] = handlerName;
    }

    final completer = Completer<T>();
    _completers[_completerIndex] = completer;
    _completerIndex += 1;

    _evaluateJavascript(jsonData);
    return completer.future;
  }

  void _nativeCallResponse(Map<String, dynamic> jsonData) {
    final int index = jsonData['index'];
    final completer = _completers[index];
    _completers.remove(index);
    if (jsonData['type'] == 'response') {
      completer?.complete(jsonData['data']);
    } else {
      completer?.completeError('native call js error for request $jsonData');
    }
  }

  void _evaluateJavascript(Map<String, dynamic> jsonData) {
    final jsonStr = jsonEncode(jsonData);
    final encodeStr = Uri.encodeFull(jsonStr);
    final script = 'WebViewJavascriptBridge.nativeCall("$encodeStr")';
    webViewController.runJavaScript(script);
  }
}

const injectJavaScript = """
(function () {
    if (window.WebViewJavascriptBridge) {
        return;
    }

    window.WebViewJavascriptBridge = {
        handlers: {},
        callbacks: {},
        index: 0,
        defaultHandler: null,

        registerHandler: _registerHandler,
        callHandler: _callHandler,
        init: _init,
        send: _send,
        nativeCall: _nativeCall,
    };


    function _registerHandler(handlerName, handler) {
        WebViewJavascriptBridge.handlers[handlerName] = handler;
    }

    function _callHandler(handlerName, data, callback) {
        if (arguments.length == 2 && typeof data == 'function') {
            callback = data;
            data = null;
        }
        _send(data, callback, handlerName);
    }

    function _init(callback) {
        WebViewJavascriptBridge.defaultHandler = callback;
    }

    function _send(data, callback, handlerName) {
        if (!data && !handlerName) {
            console.log('WebviewFlutterJSBridgeChannel: data and handlerName can not both be null at the same in WebViewJavascriptBridge send method');
            return;
        }

        var index = WebViewJavascriptBridge.index;

        var message = {
            index: index,
            type: 'request',
        };
        if (data) {
            message.data = data;
        }
        if (handlerName) {
            message.handlerName = handlerName;
        }

        WebViewJavascriptBridge.callbacks[index] = callback;
        WebViewJavascriptBridge.index += 1;

        _postMessage(message, callback);
    }


    function _jsCallResponse(jsonData) {
        var index = jsonData.index;
        var callback = WebViewJavascriptBridge.callbacks[index];
        delete WebViewJavascriptBridge.callbacks[index];
        if (jsonData.type === 'response') {
            callback(jsonData.data);
        } else {
            console.log('WebviewFlutterJSBridgeChannel: js call native error for request ', JSON.stringify(jsonData));
        }
    }

    function _postMessage(jsonData) {
        var jsonStr = JSON.stringify(jsonData);
        var encodeStr = encodeURIComponent(jsonStr);
        WebviewFlutterJSBridgeChannel.postMessage(encodeStr);
    }

    function _nativeCall(message) {
        //here can't run immediately, wtf?
        setTimeout(() => _nativeCall(message), 0);
    }

    function _nativeCall(message) {
        var decodeStr = decodeURIComponent(message);
        var jsonData = JSON.parse(decodeStr);

        if (jsonData.type === 'request') {
            if ('handlerName' in jsonData) {
                var handlerName = jsonData.handlerName;
                if (handlerName in WebViewJavascriptBridge.handlers) {
                    var handler = WebViewJavascriptBridge.handlers[jsonData.handlerName];
                    handler(jsonData.data, function (data) {
                        _nativeCallResponse(jsonData, data);
                    });
                } else {
                    _nativeCallError(jsonData);
                    console.log('WebviewFlutterJSBridgeChannel: no handler for native call ', handlerName);
                }

            } else {
                if (WebViewJavascriptBridge.defaultHandler) {
                    WebViewJavascriptBridge.defaultHandler(jsonData.data, function (data) {
                        _nativeCallResponse(jsonData, data);
                    });
                } else {
                    _nativeCallError(jsonData);
                    console.log('WebviewFlutterJSBridgeChannel: no handler for native send');
                }
            }
        } else if (jsonData.type === 'response' || jsonData.type === 'error') {
            _jsCallResponse(jsonData);
        }
    }

    function _nativeCallError(jsonData) {
        jsonData.type = 'error';
        _postMessage(jsonData);
    }

    function _nativeCallResponse(jsonData, response) {
        jsonData.type = 'response';
        jsonData.data = response;
        _postMessage(jsonData);
    }

    setTimeout(() => {
        var doc = document;
        var readyEvent = doc.createEvent('Events');
        var jobs = window.WVJBCallbacks || [];
        readyEvent.initEvent('WebViewJavascriptBridgeReady');
        readyEvent.bridge = WebViewJavascriptBridge;
        delete window.WVJBCallbacks;
        for (var i = 0; i < jobs.length; i++) {
            var job = jobs[i];
            job(WebViewJavascriptBridge);
        }
        doc.dispatchEvent(readyEvent);
    }, 0);

    return "run js success";
})();
""";
