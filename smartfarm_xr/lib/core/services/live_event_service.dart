import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'auth_service.dart';

class LiveEventService {
  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _controller;

  Stream<Map<String, dynamic>> baglan() {
    _controller ??= StreamController<Map<String, dynamic>>.broadcast();
    final String token = AuthService.instance.accessToken ?? '';
    _channel ??= WebSocketChannel.connect(
      Uri.parse('ws://127.0.0.1:8000/ws/live').replace(
        queryParameters: <String, String>{'token': token},
      ),
    );
    _channel!.stream.listen(
      (dynamic event) {
        if (_controller == null) {
          return;
        }
        try {
          if (event is String) {
            dynamic decoded = jsonDecode(event);
            if (decoded is Map) {
              _controller!.add(decoded.cast<String, dynamic>());
            }
          }
        } catch (_) {}
      },
      onError: (_) {},
      onDone: () {
        _channel = null;
      },
      cancelOnError: false,
    );
    return _controller!.stream;
  }

  void kapat() {
    _channel?.sink.close();
    _channel = null;
    _controller?.close();
    _controller = null;
  }
}
