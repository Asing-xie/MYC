import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/app_language.dart';
import '../services/api_client.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({
    super.key,
    required this.api,
    required this.currentUser,
  });

  final ApiClient api;
  final ChatUser currentUser;

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  late Future<_RequestsData> _future;
  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLanguageScope.stringsOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.newFriends)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_RequestsData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text(snapshot.error.toString())),
                ],
              );
            }
            final data = snapshot.data ?? _RequestsData.empty();
            if (data.incoming.isEmpty && data.outgoing.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text(strings.noFriendRequests)),
                ],
              );
            }
            return ListView(
              children: [
                if (data.incoming.isNotEmpty) _sectionTitle(strings.incomingRequests),
                ...data.incoming.map(_incomingTile),
                if (data.outgoing.isNotEmpty) _sectionTitle(strings.outgoingRequests),
                ...data.outgoing.map(_outgoingTile),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }

  Widget _incomingTile(ContactRelation request) {
    final strings = AppLanguageScope.stringsOf(context);
    final user = request.requester;
    final busy = _busyIds.contains(request.id);
    return ListTile(
      leading: _avatar(user),
      title: Text(user.nickname),
      subtitle: Text(user.email ?? user.phone ?? user.id),
      trailing: Wrap(
        spacing: 8,
        children: [
          OutlinedButton(
            onPressed: busy ? null : () => _reject(request),
            child: Text(strings.reject),
          ),
          FilledButton(
            onPressed: busy ? null : () => _accept(request),
            child: Text(strings.accept),
          ),
        ],
      ),
    );
  }

  Widget _outgoingTile(ContactRelation request) {
    final strings = AppLanguageScope.stringsOf(context);
    final user = request.addressee;
    return ListTile(
      leading: _avatar(user),
      title: Text(user.nickname),
      subtitle: Text(user.email ?? user.phone ?? user.id),
      trailing: Text(strings.pending),
    );
  }

  Widget _avatar(ChatUser user) {
    return CircleAvatar(
      backgroundImage: user.avatarUrl == null ? null : NetworkImage(user.avatarUrl!),
      child: user.avatarUrl == null ? Text(user.nickname.characters.first.toUpperCase()) : null,
    );
  }

  Future<_RequestsData> _load() async {
    final incoming = await widget.api.incomingContactRequests();
    final outgoing = await widget.api.outgoingContactRequests();
    return _RequestsData(incoming: incoming, outgoing: outgoing);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _accept(ContactRelation request) async {
    await _runRequestAction(
      request.id,
      () => widget.api.acceptContactRequest(request.id),
      AppLanguageScope.stringsOf(context).accepted,
    );
  }

  Future<void> _reject(ContactRelation request) async {
    await _runRequestAction(
      request.id,
      () => widget.api.rejectContactRequest(request.id),
      AppLanguageScope.stringsOf(context).rejected,
    );
  }

  Future<void> _runRequestAction(String id, Future<void> Function() action, String message) async {
    setState(() => _busyIds.add(id));
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }
}

class _RequestsData {
  _RequestsData({required this.incoming, required this.outgoing});

  final List<ContactRelation> incoming;
  final List<ContactRelation> outgoing;

  factory _RequestsData.empty() {
    return _RequestsData(incoming: [], outgoing: []);
  }
}
