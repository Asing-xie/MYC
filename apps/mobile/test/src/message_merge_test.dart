import 'package:flutter_test/flutter_test.dart';
import 'package:mwc_chat/src/models/chat_models.dart';
import 'package:mwc_chat/src/services/message_merge.dart';

void main() {
  ChatMessage message({
    required String id,
    required String senderId,
    required String content,
  }) {
    return ChatMessage(
      id: id,
      conversationId: 'c1',
      senderId: senderId,
      type: 'TEXT',
      content: content,
      status: 'SENT',
      createdAt: DateTime(2026),
    );
  }

  test('server echo replaces matching local pending message instead of duplicating it', () {
    final messages = [
      message(id: 'local-1', senderId: 'u1', content: 'hello'),
    ];

    final changed = mergeIncomingMessage(
      messages: messages,
      pendingMessageIds: {'local-1'},
      incoming: message(id: 'server-1', senderId: 'u1', content: 'hello'),
    );

    expect(changed, isTrue);
    expect(messages, hasLength(1));
    expect(messages.single.id, 'server-1');
  });

  test('duplicate server message is ignored', () {
    final messages = [
      message(id: 'server-1', senderId: 'u1', content: 'hello'),
    ];

    final changed = mergeIncomingMessage(
      messages: messages,
      pendingMessageIds: <String>{},
      incoming: message(id: 'server-1', senderId: 'u1', content: 'hello'),
    );

    expect(changed, isFalse);
    expect(messages, hasLength(1));
  });
}
