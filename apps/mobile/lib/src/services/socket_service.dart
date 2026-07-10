import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/chat_models.dart';

class SocketService {
  SocketService({required this.socketUrl});

  final String socketUrl;
  io.Socket? _socket;
  final StreamController<ChatMessage> _messages = StreamController<ChatMessage>.broadcast();
  final StreamController<MessageReadEvent> _readEvents = StreamController<MessageReadEvent>.broadcast();

  Stream<ChatMessage> get messages => _messages.stream;
  Stream<MessageReadEvent> get readEvents => _readEvents.stream;
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
    _socket!.on('message:read', (data) {
      _readEvents.add(MessageReadEvent.fromJson(Map<String, dynamic>.from(data as Map)));
    });
  }

  void joinConversation(String conversationId) {
    _socket?.emit('conversation:join', {'conversationId': conversationId});
  }

  Future<ChatMessage> sendMessage(String conversationId, String type, String? content, {int? durationMs}) {
    final socket = _socket;
    if (socket == null || !socket.connected) {
      return Future.error(StateError('Socket is not connected'));
    }

    final completer = Completer<ChatMessage>();
    socket.emitWithAck('message:send', {
      'conversationId': conversationId,
      'type': type,
      'content': content,
      if (durationMs != null) 'durationMs': durationMs,
    }, ack: (data) {
      try {
        completer.complete(ChatMessage.fromJson(Map<String, dynamic>.from(data as Map)));
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future.timeout(const Duration(seconds: 8));
  }

  Future<MessageReadEvent> markConversationRead(String conversationId) {
    final socket = _socket;
    if (socket == null || !socket.connected) {
      return Future.error(StateError('Socket is not connected'));
    }

    final completer = Completer<MessageReadEvent>();
    socket.emitWithAck('conversation:read', {'conversationId': conversationId}, ack: (data) {
      try {
        completer.complete(MessageReadEvent.fromJson(Map<String, dynamic>.from(data as Map)));
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
    _readEvents.close();
  }
}

class MessageReadEvent {
  MessageReadEvent({
    required this.conversationId,
    required this.readerId,
    required this.messageIds,
  });

  final String conversationId;
  final String readerId;
  final List<String> messageIds;

  factory MessageReadEvent.fromJson(Map<String, dynamic> json) {
    return MessageReadEvent(
      conversationId: json['conversationId'] as String,
      readerId: json['readerId'] as String,
      messageIds: (json['messageIds'] as List<dynamic>? ?? []).map((id) => id as String).toList(),
    );
  }
}
