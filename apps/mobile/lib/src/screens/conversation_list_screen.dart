import 'dart:async';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../models/chat_models.dart';
import '../services/api_client.dart';
import '../services/socket_service.dart';
import 'chat_screen.dart';
import 'contacts_screen.dart';
import 'create_group_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
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
  int _tabIndex = 0;
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
      appBar: _buildAppBar(),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          RefreshIndicator(
            onRefresh: () async {
              await _loadConversations();
              await _refreshFriendRequestBadge();
            },
            child: _buildConversationList(),
          ),
          ContactsScreen(
            api: widget.api,
            socket: widget.socket,
            currentUser: widget.currentUser,
            embedded: true,
          ),
          const _DiscoverTab(),
          ProfileScreen(
            api: widget.api,
            currentUser: widget.currentUser,
            userId: widget.currentUser.id,
            embedded: true,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) async {
          setState(() => _tabIndex = index);
          if (index == 0) _refresh();
          if (index == 1) await _refreshFriendRequestBadge();
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: '消息',
          ),
          NavigationDestination(
            icon: _friendRequestBadge > 0
                ? Badge(label: Text('$_friendRequestBadge'), child: const Icon(Icons.contacts_outlined))
                : const Icon(Icons.contacts_outlined),
            selectedIcon: _friendRequestBadge > 0
                ? Badge(label: Text('$_friendRequestBadge'), child: const Icon(Icons.contacts))
                : const Icon(Icons.contacts),
            label: '通讯录',
          ),
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: '发现',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我',
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    switch (_tabIndex) {
      case 1:
        return AppBar(title: const Text('通讯录'));
      case 2:
        return AppBar(title: const Text('发现'));
      case 3:
        return AppBar(
          title: const Text('我'),
          actions: [
            IconButton(
              tooltip: 'Settings',
              onPressed: _openSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        );
      default:
        return AppBar(
          title: const Text('消息'),
          actions: [
            IconButton(
              tooltip: 'Search users',
              onPressed: _openSearch,
              icon: const Icon(Icons.person_add_alt_1),
            ),
            IconButton(
              tooltip: 'New group',
              onPressed: _openCreateGroup,
              icon: const Icon(Icons.group_add_outlined),
            ),
          ],
        );
    }
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
        final title = conversation.displayName(widget.currentUser.id);
        final avatarUrl = conversation.displayAvatarUrl(widget.currentUser.id);
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl),
            child: avatarUrl == null
                ? Icon(conversation.isGroup ? Icons.groups_outlined : Icons.person_outline)
                : null,
          ),
          title: Text(title),
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
      setState(() => _tabIndex = 0);
      _refresh();
    }
  }

  Future<void> _openCreateGroup() async {
    final conversation = await Navigator.of(context).push<Conversation>(
      MaterialPageRoute(
        builder: (_) => CreateGroupScreen(
          api: widget.api,
          currentUser: widget.currentUser,
        ),
      ),
    );
    if (conversation != null && mounted) {
      setState(() => _tabIndex = 0);
      _refresh();
      await _openConversation(conversation);
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
        type: current.type,
        title: current.title,
        avatarUrl: current.avatarUrl,
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

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          api: widget.api,
          onLogout: _logout,
        ),
      ),
    );
  }
}

class _DiscoverTab extends StatelessWidget {
  const _DiscoverTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('发现'),
    );
  }
}
