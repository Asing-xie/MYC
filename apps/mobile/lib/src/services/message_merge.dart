import '../models/chat_models.dart';

bool mergeIncomingMessage({
  required List<ChatMessage> messages,
  required Set<String> pendingMessageIds,
  required ChatMessage incoming,
}) {
  if (messages.any((message) => message.id == incoming.id)) {
    return false;
  }

  final pendingIndex = messages.indexWhere(
    (message) =>
        pendingMessageIds.contains(message.id) &&
        message.conversationId == incoming.conversationId &&
        message.senderId == incoming.senderId &&
        message.type == incoming.type &&
        message.content == incoming.content,
  );

  if (pendingIndex >= 0) {
    pendingMessageIds.remove(messages[pendingIndex].id);
    messages[pendingIndex] = incoming;
    return true;
  }

  messages.add(incoming);
  return true;
}
