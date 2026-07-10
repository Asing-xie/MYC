import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/chat_models.dart';

class SocketService {
  SocketService({required this.socketUrl});

  final String socketUrl;
  io.Socket? _socket;
  final StreamController<ChatMessage> _messages = StreamController<ChatMessage>.broadcast();

  Stream<ChatMessage> get messages => _messages.stream;
  bool get connected => _socket?.connected ?? false;

  void connect(String token, void Function(ChatMessage message) onMessage) {
    _socket?.dispose();
    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .setPath('/socket.io')
          .enableReconnection()
          .build(),
    );
    _socket!.on('message:new', (data) {
      final message = ChatMessage.fromJson(Map<String, dynamic>.from(data as Map));
      _messages.add(message);
      onMessage(message);
    });
  }

  void joinConversation(String conversationId) {
    _socket?.emit('conversation:join', {'conversationId': conversationId});
  }

  Future<ChatMessage> sendMessage(String conversationId, String type, String? content) {
    final socket = _socket;
    if (socket == null || !socket.connected) {
      return Future.error(StateError('Socket is not connected'));
    }

    final completer = Completer<ChatMessage>();
    socket.emitWithAck('message:send', {
      'conversationId': conversationId,
      'type': type,
      'content': content,
    }, ack: (data) {
      try {
        completer.complete(ChatMessage.fromJson(Map<String, dynamic>.from(data as Map)));
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future.timeout(const Duration(seconds: 8));
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }

  void close() {
    dispose();
    _messages.close();
  }
}
