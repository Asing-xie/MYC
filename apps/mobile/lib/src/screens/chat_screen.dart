import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../models/chat_models.dart';
import '../services/api_client.dart';
import '../services/message_merge.dart';
import '../services/socket_service.dart';
import 'profile_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.api,
    required this.socket,
    required this.currentUser,
    required this.conversation,
  });

  final ApiClient api;
  final SocketService socket;
  final ChatUser currentUser;
  final Conversation conversation;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _picker = ImagePicker();
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  final List<ChatMessage> _messages = [];
  final Set<String> _pendingMessageIds = {};
  final Set<String> _failedMessageIds = {};
  StreamSubscription<ChatMessage>? _messageSub;
  StreamSubscription<MessageReadEvent>? _readSub;
  bool _loading = true;
  bool _recording = false;
  bool _sending = false;
  String? _playingUrl;

  @override
  void initState() {
    super.initState();
    widget.socket.joinConversation(widget.conversation.id);
    _messageSub = widget.socket.messages.listen((message) {
      if (message.conversationId != widget.conversation.id) return;
      if (!mounted) return;
      setState(() {
        mergeIncomingMessage(
          messages: _messages,
          pendingMessageIds: _pendingMessageIds,
          incoming: message,
        );
      });
      if (message.senderId != widget.currentUser.id) {
        _markRead();
      }
    });
    _readSub = widget.socket.readEvents.listen((event) {
      if (event.conversationId != widget.conversation.id) return;
      if (event.readerId == widget.currentUser.id) return;
      if (!mounted) return;
      final readIds = event.messageIds.toSet();
      setState(() {
        for (var index = 0; index < _messages.length; index += 1) {
          final message = _messages[index];
          if (message.senderId == widget.currentUser.id && readIds.contains(message.id)) {
            _messages[index] = message.copyWith(readByOthers: true);
          }
        }
      });
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final messages = await widget.api.messages(widget.conversation.id);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _loading = false;
      });
      _markRead();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead() async {
    try {
      await widget.socket.markConversationRead(widget.conversation.id);
    } catch (_) {
      try {
        await widget.api.markConversationRead(widget.conversation.id);
      } catch (_) {
        // Read state is best-effort and will be retried when the chat opens again.
      }
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _recorder.dispose();
    _player.dispose();
    _messageSub?.cancel();
    _readSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final peer = widget.conversation.peerFor(widget.currentUser.id);
    final title = widget.conversation.displayName(widget.currentUser.id);
    final avatarUrl = widget.conversation.displayAvatarUrl(widget.currentUser.id);
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: widget.conversation.isGroup || peer == null ? null : () => _openProfile(peer.id),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.conversation.isGroup || peer != null) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl),
                  child: avatarUrl == null
                      ? Icon(widget.conversation.isGroup ? Icons.groups_outlined : Icons.person_outline, size: 18)
                      : null,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(child: Text(title)),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final mine = message.senderId == widget.currentUser.id;
                      return _messageRow(message, mine);
                    },
                  ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox.square(
                    dimension: 42,
                    child: IconButton(
                      tooltip: 'Image',
                      onPressed: _sending ? null : _sendImage,
                      icon: const Icon(Icons.image_outlined),
                    ),
                  ),
                  SizedBox.square(
                    dimension: 42,
                    child: IconButton(
                      tooltip: _recording ? 'Stop voice' : 'Voice',
                      onPressed: _sending ? null : _toggleVoice,
                      icon: Icon(_recording ? Icons.stop_circle_outlined : Icons.mic_none),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      decoration: InputDecoration(
                        hintText: _recording ? 'Recording...' : 'Message',
                        isDense: true,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox.square(
                    dimension: 42,
                    child: IconButton(
                      tooltip: 'Send',
                      onPressed: _sending ? null : _sendText,
                      icon: _sending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageRow(ChatMessage message, bool mine) {
    final sender = _userFor(message.senderId);
    final avatar = GestureDetector(
      onTap: () => _openProfile(message.senderId),
      child: CircleAvatar(
        radius: 16,
        backgroundImage: sender?.avatarUrl == null ? null : NetworkImage(sender!.avatarUrl!),
        child: sender?.avatarUrl == null ? Text((sender?.nickname ?? '?').characters.first.toUpperCase()) : null,
      ),
    );
    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: mine ? Theme.of(context).colorScheme.primaryContainer : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _messageBody(message),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatMessageTime(message.createdAt),
                style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
              ),
              if (mine && !_pendingMessageIds.contains(message.id) && !_failedMessageIds.contains(message.id)) ...[
                const SizedBox(width: 8),
                Text(
                  message.readByOthers ? '已读' : '已送达',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                ),
              ],
            ],
          ),
          if (_pendingMessageIds.contains(message.id) || _failedMessageIds.contains(message.id))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _failedMessageIds.contains(message.id) ? '发送失败' : '发送中...',
                style: TextStyle(
                  color: _failedMessageIds.contains(message.id)
                      ? Theme.of(context).colorScheme.error
                      : Colors.grey.shade700,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
    return Row(
      mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: mine
          ? [bubble, const SizedBox(width: 8), avatar]
          : [avatar, const SizedBox(width: 8), bubble],
    );
  }

  Widget _messageBody(ChatMessage message) {
    if (message.type == 'IMAGE' && message.content != null) {
      return GestureDetector(
        onTap: () => _previewImage(message.content!),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(
            message.content!,
            width: 220,
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Text('[image unavailable]'),
          ),
        ),
      );
    }
    if (message.type == 'VOICE' && message.content != null) {
      final playing = _playingUrl == message.content;
      return InkWell(
        onTap: () => _playVoice(message.content!),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(playing ? Icons.pause_circle_outline : Icons.play_circle_outline),
            const SizedBox(width: 8),
            Text('语音 ${_formatDuration(message.durationMs)}'),
          ],
        ),
      );
    }
    return Text(message.content ?? '');
  }

  Future<void> _sendText() async {
    final content = _text.text.trim();
    if (content.isEmpty) return;
    _text.clear();
    await _sendTyped('TEXT', content);
  }

  ChatUser? _userFor(String userId) {
    if (widget.currentUser.id == userId) return widget.currentUser;
    for (final member in widget.conversation.members) {
      if (member.id == userId) return member;
    }
    return null;
  }

  Future<void> _openProfile(String userId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          api: widget.api,
          currentUser: widget.currentUser,
          userId: userId,
        ),
      ),
    );
  }

  Future<void> _sendTyped(String type, String content, {int? durationMs}) async {
    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final localMessage = ChatMessage(
      id: localId,
      conversationId: widget.conversation.id,
      senderId: widget.currentUser.id,
      type: type,
      content: content,
      durationMs: durationMs,
      status: 'SENDING',
      createdAt: DateTime.now(),
    );
    setState(() {
      _sending = true;
      _pendingMessageIds.add(localId);
      _messages.add(localMessage);
    });

    try {
      final message = await _sendPersisted(type, content, durationMs: durationMs);
      if (!mounted) return;
      setState(() {
        mergeIncomingMessage(
          messages: _messages,
          pendingMessageIds: _pendingMessageIds,
          incoming: message,
        );
        _pendingMessageIds.remove(localId);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pendingMessageIds.remove(localId);
        _failedMessageIds.add(localId);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('消息发送失败')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<ChatMessage> _sendPersisted(String type, String content, {int? durationMs}) async {
    try {
      return await widget.socket.sendMessage(widget.conversation.id, type, content, durationMs: durationMs);
    } catch (_) {
      return widget.api.sendMessage(widget.conversation.id, type, content, durationMs: durationMs);
    }
  }

  Future<void> _sendImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;
    await _uploadAndSend('IMAGE', File(image.path));
  }

  Future<void> _toggleVoice() async {
    if (_recording) {
      final path = await _recorder.stop();
      setState(() => _recording = false);
      if (path != null) {
        final file = File(path);
        final durationMs = await _voiceDurationMs(file);
        await _uploadAndSend('VOICE', file, durationMs: durationMs);
      }
      return;
    }

    final allowed = await _recorder.hasPermission();
    if (!allowed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission denied')));
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    if (!mounted) return;
    setState(() => _recording = true);
  }

  Future<void> _uploadAndSend(String type, File file, {int? durationMs}) async {
    try {
      setState(() => _sending = true);
      final attachment = await widget.api.uploadFile(type, file);
      final url = attachment['url'] as String;
      await _sendTyped(type, url, durationMs: durationMs);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _playVoice(String url) async {
    if (_playingUrl == url) {
      await _player.pause();
      if (mounted) setState(() => _playingUrl = null);
      return;
    }
    await _player.setUrl(url);
    if (!mounted) return;
    setState(() => _playingUrl = url);
    await _player.play();
    if (mounted) setState(() => _playingUrl = null);
  }

  Future<int?> _voiceDurationMs(File file) async {
    final probe = AudioPlayer();
    try {
      final duration = await probe.setFilePath(file.path);
      return duration?.inMilliseconds;
    } catch (_) {
      return null;
    } finally {
      await probe.dispose();
    }
  }

  void _previewImage(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
          backgroundColor: Colors.black,
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(int? durationMs) {
    if (durationMs == null || durationMs <= 0) return '';
    final seconds = (durationMs / 1000).ceil();
    return '$seconds"';
  }

  String _formatMessageTime(DateTime time) {
    final local = time.toLocal();
    final now = DateTime.now();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    if (local.year == now.year && local.month == now.month && local.day == now.day) {
      return '$hh:$mm';
    }
    return '${local.month}/${local.day} $hh:$mm';
  }
}
