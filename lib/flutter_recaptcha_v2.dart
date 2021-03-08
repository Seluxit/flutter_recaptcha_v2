library flutter_recaptcha_v2;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

typedef ValueValueChanged<T, U> = void Function(T t, U u);

class RecaptchaV2 extends StatefulWidget {
  final String apiKey;
  final String apiSecret;
  final String pluginURL;
  final RecaptchaV2Controller controller;
  final bool visibleCancelButton;
  final String textCancelButton;

  final ValueValueChanged<bool, String> onVerifiedSuccessfully;
  final ValueValueChanged<String, String> onVerifiedError;

  RecaptchaV2({
    required this.apiKey,
    this.apiSecret = "",
    this.pluginURL: "https://recaptcha-flutter-plugin.firebaseapp.com/",
    this.visibleCancelButton: false,
    this.textCancelButton: "CANCEL CAPTCHA",
    required this.controller,
    required this.onVerifiedSuccessfully,
    required this.onVerifiedError,
  }) : assert(apiKey.isNotEmpty, "Google ReCaptcha API KEY is missing.");

  @override
  State<StatefulWidget> createState() => _RecaptchaV2State();
}

class _RecaptchaV2State extends State<RecaptchaV2> {
  final Completer<WebViewController> _controller = Completer<WebViewController>();

  void verifyToken(String token) async {
    if (widget.apiSecret.isEmpty) {
      widget.onVerifiedSuccessfully(true, token);
    } else {
      Uri url = Uri.parse("https://www.google.com/recaptcha/api/siteverify");
      http.Response response = await http.post(url, body: {
        "secret": widget.apiSecret,
        "response": token,
      });

      if (response.statusCode == 200) {
        dynamic json = jsonDecode(response.body);
        if (json['success']) {
          widget.onVerifiedSuccessfully(true, token);
        } else {
          widget.onVerifiedSuccessfully(false, token);
          widget.onVerifiedError(json['error-codes'].toString(), token);
        }
      }
    }

    // hide captcha
    widget.controller.hide();
  }

  void onListen() {
    if (widget.controller.visible) {
      _controller.future.then((WebViewController con) {
        con.clearCache();
        con.reload();
      });
    }
    setState(() {
      widget.controller.visible;
    });
  }

  @override
  void initState() {
    widget.controller.addListener(onListen);
    super.initState();
  }

  @override
  void didUpdateWidget(RecaptchaV2 oldWidget) {
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(onListen);
      widget.controller.removeListener(onListen);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    widget.controller.removeListener(onListen);
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.controller.visible
        ? Stack(
            children: <Widget>[
              WebView(
                initialUrl: "${widget.pluginURL}?api_key=${widget.apiKey}",
                javascriptMode: JavascriptMode.unrestricted,
                javascriptChannels: <JavascriptChannel>[
                  JavascriptChannel(
                    name: 'RecaptchaFlutterChannel',
                    onMessageReceived: (JavascriptMessage receiver) {
                      String _token = receiver.message;
                      if (_token.contains("verify")) {
                        _token = _token.substring(7);
                      }
                      verifyToken(_token);
                    },
                  ),
                ].toSet(),
                onWebViewCreated: (WebViewController webViewController) {
                  _controller.complete(webViewController);
                },
              ),
              Visibility(
                visible: widget.visibleCancelButton,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height: 60,
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: <Widget>[
                        Expanded(
                          child: ElevatedButton(
                            child: Text(widget.textCancelButton),
                            onPressed: () {
                              widget.controller.hide();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          )
        : Container();
  }
}

class RecaptchaV2Controller extends ChangeNotifier {
  bool isDisposed = false;
  List<VoidCallback> _listeners = [];

  bool _visible = false;

  bool get visible => _visible;

  void show() {
    _visible = true;
    if (!isDisposed) notifyListeners();
  }

  void hide() {
    _visible = false;
    if (!isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _listeners = [];
    isDisposed = true;
    super.dispose();
  }

  @override
  void addListener(listener) {
    _listeners.add(listener);
    super.addListener(listener);
  }

  @override
  void removeListener(listener) {
    _listeners.remove(listener);
    super.removeListener(listener);
  }
}
