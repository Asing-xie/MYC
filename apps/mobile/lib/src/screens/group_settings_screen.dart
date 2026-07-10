import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/api_client.dart';
import '../services/app_language.dart';

class GroupSettingsResult {
  const GroupSettingsResult.updated(this.conversation) : closed = false;
  const GroupSettingsResult.closed()
      : conversation = null,
        closed = true;

  final Conversation? conversation;
  final bool closed;
}

class GroupSettingsScreen extends StatefulWidget {
  const GroupSettingsScreen({
    super.key,
    required this.api,
    required this.currentUser,
    required this.conversation,
  });

  final ApiClient api;
  final ChatUser currentUser;
  final Conversation conversation;

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  late Conversation _conversation;
  late final TextEditingController _title;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _canManage => _conversation.canManage(widget.currentUser.id);
  bool get _isOwner =>
      _conversation.memberFor(widget.currentUser.id)?.isGroupOwner == true;

  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    _title = TextEditingController(
        text: _conversation.displayName(widget.currentUser.id));
    _load();
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
        leading: BackButton(onPressed: _closeWithUpdate),
        title: Text(strings.groupSettings),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (_error != null) ...[
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _title,
                  enabled: _canManage && !_saving,
                  decoration: InputDecoration(
                    labelText: strings.groupName,
                    border: const OutlineInputBorder(),
                    suffixIcon: _canManage
                        ? IconButton(
                            tooltip: strings.saveGroupName,
                            onPressed: _saving ? null : _saveTitle,
                            icon: _saving
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.check),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${strings.groupMembers} (${_conversation.members.length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (_canManage)
                      IconButton(
                        tooltip: strings.addMembers,
                        onPressed: _saving ? null : _addMembers,
                        icon: const Icon(Icons.person_add_alt_1),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                ..._conversation.members.map(_memberTile),
                const SizedBox(height: 24),
                if (!_isOwner)
                  FilledButton.tonalIcon(
                    onPressed: _saving ? null : _leaveGroup,
                    icon: const Icon(Icons.logout),
                    label: Text(strings.leaveGroup),
                  ),
                if (_canManage) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
                    onPressed: _saving ? null : _deleteGroup,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(strings.dissolveGroup),
                  ),
                ],
              ],
            ),
    );
  }

  void _closeWithUpdate() {
    Navigator.of(context).pop(GroupSettingsResult.updated(_conversation));
  }

  Widget _memberTile(ChatUser member) {
    final strings = AppLanguageScope.stringsOf(context);
    final canRemove = _canManage &&
        member.id != widget.currentUser.id &&
        !member.isGroupOwner;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundImage:
            member.avatarUrl == null ? null : NetworkImage(member.avatarUrl!),
        child: member.avatarUrl == null
            ? Text(member.nickname.characters.first.toUpperCase())
            : null,
      ),
      title: Text(member.nickname),
      subtitle: Text(member.isGroupOwner ? strings.owner : strings.member),
      trailing: canRemove
          ? IconButton(
              tooltip: strings.removeMember,
              onPressed: _saving ? null : () => _removeMember(member),
              icon: const Icon(Icons.person_remove_outlined),
            )
          : null,
    );
  }

  Future<void> _load() async {
    try {
      final conversation =
          await widget.api.conversation(widget.conversation.id);
      if (!mounted) return;
      setState(() {
        _conversation = conversation;
        _title.text = conversation.displayName(widget.currentUser.id);
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _saveTitle() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    await _updateConversation(
        () => widget.api.updateGroupTitle(_conversation.id, title));
  }

  Future<void> _addMembers() async {
    final strings = AppLanguageScope.stringsOf(context);
    setState(() => _saving = true);
    try {
      final contacts = await widget.api.contacts();
      if (!mounted) return;
      final existingIds =
          _conversation.members.map((member) => member.id).toSet();
      final candidates = contacts
          .map((contact) => contact.friendFor(widget.currentUser.id))
          .where((friend) => !existingIds.contains(friend.id))
          .toList();
      if (candidates.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(strings.noAvailableFriends)));
        return;
      }
      final selectedIds = await _selectMembers(candidates);
      if (selectedIds == null || selectedIds.isEmpty) return;
      await _updateConversation(
          () => widget.api.addGroupMembers(_conversation.id, selectedIds),
          setBusy: false);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<List<String>?> _selectMembers(List<ChatUser> candidates) {
    final strings = AppLanguageScope.stringsOf(context);
    final selected = <String>{};
    return showDialog<List<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(strings.addMembers),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  itemBuilder: (context, index) {
                    final friend = candidates[index];
                    return CheckboxListTile(
                      value: selected.contains(friend.id),
                      onChanged: (checked) {
                        setDialogState(() {
                          if (checked == true) {
                            selected.add(friend.id);
                          } else {
                            selected.remove(friend.id);
                          }
                        });
                      },
                      title: Text(friend.nickname),
                      subtitle: Text(friend.email ?? friend.phone ?? friend.id),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(strings.cancel)),
                FilledButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(selected.toList()),
                  child: Text(strings.addMembers),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _removeMember(ChatUser member) async {
    final strings = AppLanguageScope.stringsOf(context);
    final confirmed = await _confirm(
        strings.removeMember, strings.removeMemberConfirm(member.nickname));
    if (!confirmed) return;
    await _updateConversation(
        () => widget.api.removeGroupMember(_conversation.id, member.id));
  }

  Future<void> _leaveGroup() async {
    final strings = AppLanguageScope.stringsOf(context);
    final confirmed =
        await _confirm(strings.leaveGroup, strings.leaveGroupConfirm);
    if (!confirmed) return;
    setState(() => _saving = true);
    try {
      await widget.api.leaveGroup(_conversation.id);
      if (!mounted) return;
      Navigator.of(context).pop(const GroupSettingsResult.closed());
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteGroup() async {
    final strings = AppLanguageScope.stringsOf(context);
    final confirmed =
        await _confirm(strings.dissolveGroup, strings.dissolveGroupConfirm);
    if (!confirmed) return;
    setState(() => _saving = true);
    try {
      await widget.api.deleteGroup(_conversation.id);
      if (!mounted) return;
      Navigator.of(context).pop(const GroupSettingsResult.closed());
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateConversation(Future<Conversation> Function() action,
      {bool setBusy = true}) async {
    if (setBusy) setState(() => _saving = true);
    try {
      final conversation = await action();
      if (!mounted) return;
      setState(() {
        _conversation = conversation;
        _title.text = conversation.displayName(widget.currentUser.id);
        _error = null;
      });
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted && setBusy) setState(() => _saving = false);
    }
  }

  Future<bool> _confirm(String title, String content) async {
    final strings = AppLanguageScope.stringsOf(context);
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(strings.cancel)),
              FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(strings.accept)),
            ],
          ),
        ) ??
        false;
  }

  void _showError(Object error) {
    setState(() => _error = error.toString());
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.toString())));
  }
}
