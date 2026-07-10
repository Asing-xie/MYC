import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/app_language.dart';
import '../services/api_client.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({
    super.key,
    required this.api,
    required this.currentUser,
  });

  final ApiClient api;
  final ChatUser currentUser;

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _title = TextEditingController();
  final Set<String> _selectedIds = {};
  late Future<List<ContactRelation>> _contactsFuture;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _contactsFuture = widget.api.contacts();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLanguageScope.stringsOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.newGroup),
        actions: [
          TextButton(
            onPressed: _selectedIds.length < 2 || _creating ? null : _create,
            child: _creating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(strings.create),
          ),
        ],
      ),
      body: FutureBuilder<List<ContactRelation>>(
        future: _contactsFuture,
        builder: (context, snapshot) {
          final contacts = snapshot.data ?? [];
          if (snapshot.connectionState != ConnectionState.done && contacts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && contacts.isEmpty) {
            return Center(child: Text(snapshot.error.toString()));
          }
          if (contacts.length < 2) {
            return Center(child: Text(strings.atLeastTwoFriends));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _title,
                  decoration: InputDecoration(
                    labelText: strings.groupName,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(strings.selectedCount(_selectedIds.length, contacts.length)),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: contacts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final friend = contacts[index].friendFor(widget.currentUser.id);
                    final selected = _selectedIds.contains(friend.id);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: _creating ? null : (_) => _toggle(friend.id),
                      secondary: CircleAvatar(
                        backgroundImage: friend.avatarUrl == null ? null : NetworkImage(friend.avatarUrl!),
                        child: friend.avatarUrl == null
                            ? Text(friend.nickname.characters.first.toUpperCase())
                            : null,
                      ),
                      title: Text(friend.nickname),
                      subtitle: Text(friend.email ?? friend.phone ?? friend.id),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _toggle(String userId) {
    setState(() {
      if (_selectedIds.contains(userId)) {
        _selectedIds.remove(userId);
      } else {
        _selectedIds.add(userId);
      }
    });
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    try {
      final conversation = await widget.api.createGroupConversation(
        title: _title.text.trim(),
        memberIds: _selectedIds.toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(conversation);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}
