import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/chat_models.dart';
import '../services/app_language.dart';
import '../services/api_client.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.api,
    required this.currentUser,
    required this.userId,
    this.embedded = false,
  });

  final ApiClient api;
  final ChatUser currentUser;
  final String userId;
  final bool embedded;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _picker = ImagePicker();
  ChatUser? _profile;
  List<AlbumPhoto> _photos = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isMe => widget.userId == widget.currentUser.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLanguageScope.stringsOf(context);
    final profile = _profile;
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                if (profile != null) _profileHeader(profile),
                const SizedBox(height: 24),
                _sectionTitle(strings.album),
                const SizedBox(height: 10),
                if (_isMe)
                  Align(
                    alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : _addAlbumImage,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(strings.addPhoto),
                    ),
                  ),
                const SizedBox(height: 12),
                _albumGrid(),
              ],
            ),
          );
    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(title: Text(_isMe ? strings.myProfile : strings.profile)),
      body: body,
    );
  }

  Widget _profileHeader(ChatUser user) {
    final strings = AppLanguageScope.stringsOf(context);
    final subtitle = user.email ?? user.phone ?? user.id;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _isMe && !_saving ? _changeAvatar : null,
          child: CircleAvatar(
            radius: 42,
            backgroundImage: user.avatarUrl == null ? null : NetworkImage(user.avatarUrl!),
            child: user.avatarUrl == null ? Text(user.nickname.characters.first.toUpperCase()) : null,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(user.nickname, style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  if (_isMe)
                    IconButton(
                      tooltip: strings.editProfile,
                      onPressed: _saving ? null : _editProfile,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              Text(
                (user.signature?.trim().isNotEmpty ?? false) ? user.signature!.trim() : strings.noSignature,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (_isMe)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    strings.tapAvatarToUpdate,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }

  Widget _albumGrid() {
    final strings = AppLanguageScope.stringsOf(context);
    if (_photos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(child: Text(_isMe ? strings.noPhotosYet : strings.noPublicPhotos)),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _photos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final photo = _photos[index];
        return GestureDetector(
          onTap: () => _previewImage(photo.url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              photo.url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _load() async {
    try {
      final profile = await widget.api.userProfile(widget.userId);
      final photos = await widget.api.albumPhotos(widget.userId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _photos = photos;
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

  Future<void> _changeAvatar() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;
    await _runSaving(() async {
      final upload = await widget.api.uploadFile('IMAGE', File(image.path));
      final updated = await widget.api.updateProfile(avatarUrl: upload['url'] as String);
      setState(() => _profile = updated);
    });
  }

  Future<void> _addAlbumImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;
    await _runSaving(() async {
      final upload = await widget.api.uploadFile('IMAGE', File(image.path));
      await widget.api.addAlbumPhoto(upload['url'] as String);
      final photos = await widget.api.albumPhotos(widget.userId);
      setState(() => _photos = photos);
    });
  }

  Future<void> _editProfile() async {
    final strings = AppLanguageScope.stringsOf(context);
    final profile = _profile;
    if (profile == null) return;
    final nickname = TextEditingController(text: profile.nickname);
    final signature = TextEditingController(text: profile.signature ?? '');
    final result = await showDialog<({String nickname, String signature})>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.editProfile),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nickname,
              decoration: InputDecoration(labelText: strings.nickname),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: signature,
              decoration: InputDecoration(labelText: strings.signature),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(strings.cancel)),
          FilledButton(
            onPressed: () => Navigator.of(context).pop((
              nickname: nickname.text.trim(),
              signature: signature.text.trim(),
            )),
            child: Text(strings.save),
          ),
        ],
      ),
    );
    nickname.dispose();
    signature.dispose();
    if (result == null || result.nickname.isEmpty) return;

    await _runSaving(() async {
      final updated = await widget.api.updateProfile(
        nickname: result.nickname,
        signature: result.signature,
      );
      setState(() => _profile = updated);
    });
  }

  Future<void> _runSaving(Future<void> Function() action) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _previewImage(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(),
          backgroundColor: Colors.black,
          body: Center(
            child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}
