import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../models/chat_models.dart';
import '../services/api_client.dart';
import '../services/socket_service.dart';
import 'chat_screen.dart';
import 'contacts_screen.dart';
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
  late Future<List<Conversation>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.conversations();
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
            icon: const Icon(Icons.contacts_outlined),
            label: const Text('Contacts'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') _logout();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _future = widget.api.conversations());
          await _future;
        },
        child: FutureBuilder<List<Conversation>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            final conversations = snapshot.data ?? [];
            if (conversations.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 160),
                  Center(child: Text('No conversations yet')),
                ],
              );
            }
            return ListView.separated(
              itemCount: conversations.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                final peer = conversation.peerFor(widget.currentUser.id);
                return ListTile(
                  title: Text(peer?.nickname ?? 'Chat'),
                  subtitle: Text(
                    conversation.latestPreview(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: conversation.unread > 0 ? Badge(label: Text('${conversation.unread}')) : null,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        api: widget.api,
                        socket: widget.socket,
                        currentUser: widget.currentUser,
                        conversation: conversation,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
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
    if (mounted) _refresh();
  }

  void _refresh() {
    setState(() => _future = widget.api.conversations());
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
