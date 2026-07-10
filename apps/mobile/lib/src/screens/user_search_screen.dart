import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/api_client.dart';
import '../services/socket_service.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({
    super.key,
    required this.api,
    required this.socket,
    required this.currentUser,
  });

  final ApiClient api;
  final SocketService socket;
  final ChatUser currentUser;

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final _query = TextEditingController();
  List<ChatUser> _users = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;
  Timer? _debounce;
  final Set<String> _busyUserIds = {};
  final Set<String> _requestedUserIds = {};

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search users')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _query,
                decoration: InputDecoration(
                  labelText: 'Email, phone, or nickname',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_query.text.isNotEmpty)
                        IconButton(
                          tooltip: 'Clear',
                          onPressed: _clear,
                          icon: const Icon(Icons.clear),
                        ),
                      IconButton(
                        tooltip: 'Search',
                        onPressed: _search,
                        icon: const Icon(Icons.search),
                      ),
                    ],
                  ),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                onChanged: _onQueryChanged,
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            Expanded(
              child: _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (!_searched && _users.isEmpty) {
      return const Center(child: Text('Search by email, phone, or nickname'));
    }
    if (_searched && !_loading && _users.isEmpty) {
      return const Center(child: Text('No users found'));
    }
    return ListView.separated(
      itemCount: _users.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final user = _users[index];
        final busy = _busyUserIds.contains(user.id);
        final requested = _requestedUserIds.contains(user.id);
        return ListTile(
          leading: GestureDetector(
            onTap: () => _openProfile(user.id),
            child: CircleAvatar(
              backgroundImage: user.avatarUrl == null ? null : NetworkImage(user.avatarUrl!),
              child: user.avatarUrl == null ? Text(user.nickname.characters.first.toUpperCase()) : null,
            ),
          ),
          title: Text(user.nickname),
          subtitle: Text(user.email ?? user.phone ?? user.id),
          trailing: IconButton(
            tooltip: requested ? 'Request sent' : 'Add friend',
            onPressed: busy || requested ? null : () => _addOrChat(user),
            icon: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(requested ? Icons.check_circle_outline : Icons.person_add_alt_1),
          ),
          onTap: busy || requested ? null : () => _addOrChat(user),
        );
      },
    );
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    setState(() {});
    if (q.length < 2) {
      setState(() {
        _users = [];
        _searched = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  void _clear() {
    _debounce?.cancel();
    _query.clear();
    setState(() {
      _users = [];
      _searched = false;
      _error = null;
      _busyUserIds.clear();
      _requestedUserIds.clear();
    });
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 2) return;
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
    });
    try {
      final users = await widget.api.searchUsers(q);
      if (!mounted) return;
      setState(() => _users = users);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addOrChat(ChatUser user) async {
    setState(() {
      _busyUserIds.add(user.id);
      _error = null;
    });
    try {
      if (widget.currentUser.isGm) {
        final conversation = await widget.api.createDirectConversation(user.id);
        await _openConversation(conversation);
      } else {
        final relation = await widget.api.sendContactRequest(user.id);
        if (!mounted) return;
        final message = relation.status == 'ACCEPTED' ? 'Already friends' : 'Friend request sent';
        setState(() {
          _requestedUserIds.add(user.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _busyUserIds.remove(user.id);
        });
      }
    }
  }

  Future<void> _openConversation(Conversation conversation) async {
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
}
