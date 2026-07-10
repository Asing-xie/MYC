import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/api_client.dart';
import '../services/socket_service.dart';
import 'chat_screen.dart';
import 'friend_requests_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({
    super.key,
    required this.api,
    required this.socket,
    required this.currentUser,
  });

  final ApiClient api;
  final SocketService socket;
  final ChatUser currentUser;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  late Future<List<ContactRelation>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.contacts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<ContactRelation>>(
          future: _future,
          builder: (context, snapshot) {
            final contacts = snapshot.data ?? [];
            return ListView.separated(
              itemCount: contacts.length + 1,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person_add_alt_1)),
                    title: const Text('New Friends'),
                    subtitle: const Text('Friend requests'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _openRequests,
                  );
                }
                if (snapshot.connectionState != ConnectionState.done && contacts.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 120),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError && contacts.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(child: Text(snapshot.error.toString())),
                  );
                }
                final relation = contacts[index - 1];
                final friend = relation.friendFor(widget.currentUser.id);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: friend.avatarUrl == null ? null : NetworkImage(friend.avatarUrl!),
                    child: friend.avatarUrl == null ? Text(friend.nickname.characters.first.toUpperCase()) : null,
                  ),
                  title: Text(friend.nickname),
                  subtitle: Text(friend.email ?? friend.phone ?? friend.id),
                  onTap: () => _startChat(friend),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = widget.api.contacts();
    });
    await _future;
  }

  Future<void> _openRequests() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FriendRequestsScreen(
          api: widget.api,
          currentUser: widget.currentUser,
        ),
      ),
    );
    if (mounted) _refresh();
  }

  Future<void> _startChat(ChatUser friend) async {
    try {
      final conversation = await widget.api.createDirectConversation(friend.id);
      if (!mounted) return;
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
      if (mounted) Navigator.of(context).pop(conversation);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}
