class ChatUser {
  ChatUser({
    required this.id,
    required this.nickname,
    this.email,
    this.phone,
    this.avatarUrl,
    this.signature,
    this.role = 'USER',
  });

  final String id;
  final String nickname;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String? signature;
  final String role;

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      id: json['id'] as String,
      nickname: json['nickname'] as String? ?? 'User',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      signature: json['signature'] as String?,
      role: json['role'] as String? ?? 'USER',
    );
  }

  bool get isGm => role == 'GM';
}

class AlbumPhoto {
  AlbumPhoto({
    required this.id,
    required this.url,
    this.caption,
    required this.createdAt,
  });

  final String id;
  final String url;
  final String? caption;
  final DateTime createdAt;

  factory AlbumPhoto.fromJson(Map<String, dynamic> json) {
    return AlbumPhoto(
      id: json['id'] as String,
      url: json['url'] as String,
      caption: json['caption'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class Conversation {
  Conversation({
    required this.id,
    required this.members,
    this.latestMessage,
    this.unread = 0,
  });

  final String id;
  final List<ChatUser> members;
  final ChatMessage? latestMessage;
  final int unread;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final membersJson = (json['members'] as List<dynamic>? ?? []);
    return Conversation(
      id: json['id'] as String,
      members: membersJson
          .map((member) => ChatUser.fromJson((member as Map<String, dynamic>)['user'] as Map<String, dynamic>))
          .toList(),
      latestMessage: json['latestMessage'] == null
          ? null
          : ChatMessage.fromJson(json['latestMessage'] as Map<String, dynamic>),
      unread: json['unread'] as int? ?? 0,
    );
  }

  ChatUser? peerFor(String currentUserId) {
    for (final member in members) {
      if (member.id != currentUserId) return member;
    }
    return members.isEmpty ? null : members.first;
  }

  String latestPreview() {
    final message = latestMessage;
    if (message == null) return 'No messages yet';
    return message.previewText();
  }
}

class ContactRelation {
  ContactRelation({
    required this.id,
    required this.status,
    required this.requester,
    required this.addressee,
  });

  final String id;
  final String status;
  final ChatUser requester;
  final ChatUser addressee;

  factory ContactRelation.fromJson(Map<String, dynamic> json) {
    return ContactRelation(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'PENDING',
      requester: ChatUser.fromJson(json['requester'] as Map<String, dynamic>),
      addressee: ChatUser.fromJson(json['addressee'] as Map<String, dynamic>),
    );
  }

  ChatUser friendFor(String currentUserId) {
    return requester.id == currentUserId ? addressee : requester;
  }

  ChatUser requestPeerFor(String currentUserId) {
    return requester.id == currentUserId ? addressee : requester;
  }
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    this.content,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String type;
  final String? content;
  final String status;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      senderId: json['senderId'] as String,
      type: json['type'] as String,
      content: json['content'] as String?,
      status: json['status'] as String? ?? 'SENT',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  String previewText() {
    if (type == 'IMAGE') return '[图片]';
    if (type == 'VOICE') return '[语音]';
    return content ?? '';
  }
}
