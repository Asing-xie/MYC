import 'dart:async';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../models/chat_models.dart';
import '../services/api_client.dart';
import '../services/socket_service.dart';
import 'chat_screen.dart';
import 'contacts_screen.dart';
import 'profile_screen.dart';
import 'user_search_screen.dart';

class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({
    super.key,
    required this.api,
    required this.socket,
    required this.currentUser,
  });

  final ApiClient api;
  final SocketService socket;
  final ChatUser currentUser;

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  final List<Conversation> _conversations = [];
  StreamSubscription<ChatMessage>? _messageSub;
  int _friendRequestBadge = 0;
  bool _initialLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConversations(showInitialLoading: true);
    _refreshFriendRequestBadge();
    _messageSub = widget.socket.messages.listen((_) {
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            tooltip: 'Search users',
            onPressed: _openSearch,
            icon: const Icon(Icons.person_add_alt_1),
          ),
          TextButton.icon(
            onPressed: _openContacts,
            icon: _friendRequestBadge > 0
                ? Badge(
                    label: Text('$_friendRequestBadge'),
                    child: const Icon(Icons.contacts_outlined),
                  )
                : const Icon(Icons.contacts_outlined),
            label: const Text('Contacts'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'profile') _openMyProfile();
              if (value == 'logout') _logout();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'profile', child: Text('My Profile')),
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadConversations();
          await _refreshFriendRequestBadge();
        },
        child: _buildConversationList(),
      ),
    );
  }

  Widget _buildConversationList() {
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _conversations.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 160),
          Center(child: Text(_error!)),
        ],
      );
    }
    if (_conversations.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 160),
          Center(child: Text('No conversations yet')),
        ],
      );
    }
    return ListView.separated(
      itemCount: _conversations.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final conversation = _conversations[index];
        final peer = conversation.peerFor(widget.currentUser.id);
        return ListTile(
          title: Text(peer?.nickname ?? 'Chat'),
          subtitle: Text(
            conversation.latestPreview(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: conversation.unread > 0 ? Badge(label: Text('${conversation.unread}')) : null,
          onTap: () => _openConversation(conversation),
        );
      },
    );
  }

  Future<void> _openSearch() async {
    final conversation = await Navigator.of(context).push<Conversation>(
      MaterialPageRoute(
        builder: (_) => UserSearchScreen(
          api: widget.api,
          socket: widget.socket,
          currentUser: widget.currentUser,
        ),
      ),
    );
    if (conversation != null && mounted) {
      _refresh();
    }
  }

  Future<void> _openContacts() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContactsScreen(
          api: widget.api,
          socket: widget.socket,
          currentUser: widget.currentUser,
        ),
      ),
    );
    if (mounted) {
      _refresh();
      await _refreshFriendRequestBadge();
    }
  }

  void _refresh() {
    _loadConversations();
  }

  Future<void> _loadConversations({bool showInitialLoading = false}) async {
    if (showInitialLoading && mounted) {
      setState(() {
        _initialLoading = true;
        _error = null;
      });
    }
    try {
      final conversations = await widget.api.conversations();
      if (!mounted) return;
      setState(() {
        _conversations
          ..clear()
          ..addAll(conversations);
        _initialLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initialLoading = false;
        _error = error.toString();
      });
    }
  }

  void _removeUnreadFor(String conversationId) {
    setState(() {
      final index = _conversations.indexWhere((conversation) => conversation.id == conversationId);
      if (index == -1) return;
      final current = _conversations[index];
      _conversations[index] = Conversation(
        id: current.id,
        members: current.members,
        latestMessage: current.latestMessage,
        unread: 0,
      );
    });
  }

  Future<void> _refreshFriendRequestBadge() async {
    try {
      final count = await widget.api.unseenIncomingContactRequestCount();
      if (mounted) {
        setState(() {
          _friendRequestBadge = count;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _friendRequestBadge = 0;
        });
      }
    }
  }

  Future<void> _openConversation(Conversation conversation) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          api: widget.api,
          socket: widget.socket,
          currentUser: widget.currentUser,
          conversation: conversation,
        ),
      ),
    );
    try {
      await widget.api.markConversationRead(conversation.id);
    } catch (_) {
      // ChatScreen also marks messages read; keep the list refresh best-effort.
    }
    if (mounted) {
      _removeUnreadFor(conversation.id);
      _refresh();
    }
  }

  Future<void> _openMyProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          api: widget.api,
          currentUser: widget.currentUser,
          userId: widget.currentUser.id,
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await widget.api.logout();
    widget.socket.dispose();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          api: widget.api,
          socket: widget.socket,
          restoreSession: false,
        ),
      ),
      (_) => false,
    );
  }
}
