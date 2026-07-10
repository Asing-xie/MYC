import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/app_language.dart';
import '../services/api_client.dart';
import '../services/socket_service.dart';
import 'conversation_list_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.api,
    required this.socket,
    this.restoreSession = true,
  });

  final ApiClient api;
  final SocketService socket;
  final bool restoreSession;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identity = TextEditingController();
  final _password = TextEditingController();
  final _nickname = TextEditingController();
  bool _register = false;
  bool _loading = false;
  bool _checkingSession = true;

  @override
  void initState() {
    super.initState();
    if (widget.restoreSession) {
      _restoreSession();
    } else {
      _checkingSession = false;
    }
  }

  @override
  void dispose() {
    _identity.dispose();
    _password.dispose();
    _nickname.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLanguageScope.stringsOf(context);
    final language = AppLanguageScope.controllerOf(context);
    if (_checkingSession) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.appName),
        actions: [
          TextButton.icon(
            onPressed: language.toggle,
            icon: const Icon(Icons.language_outlined),
            label: Text(strings.languageToggle),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _identity,
              decoration: InputDecoration(labelText: strings.emailOrPhone),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              decoration: InputDecoration(labelText: strings.password),
              obscureText: true,
            ),
            if (_register) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _nickname,
                decoration: InputDecoration(labelText: strings.nickname),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: Text(_register ? strings.register : strings.login),
            ),
            TextButton(
              onPressed: _loading ? null : () => setState(() => _register = !_register),
              child: Text(_register ? strings.useExistingAccount : strings.createAccount),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      late final ChatUser user;
      if (_register) {
        user = await widget.api.register(_identity.text, _password.text, _nickname.text);
      } else {
        user = await widget.api.login(_identity.text, _password.text);
      }
      final token = await widget.api.token;
      if (token != null) {
        widget.socket.connect(token, (_) {});
      }
      _openConversations(user);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restoreSession() async {
    try {
      final token = await widget.api.token;
      if (token == null) {
        if (mounted) setState(() => _checkingSession = false);
        return;
      }

      final user = await widget.api.me();
      widget.socket.connect(token, (_) {});
      _openConversations(user);
    } catch (_) {
      await widget.api.logout();
      if (mounted) setState(() => _checkingSession = false);
    }
  }

  void _openConversations(ChatUser user) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ConversationListScreen(api: widget.api, socket: widget.socket, currentUser: user),
        ),
      );
    });
  }
}
