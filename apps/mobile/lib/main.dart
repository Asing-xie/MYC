import 'package:flutter/material.dart';
import 'src/screens/login_screen.dart';
import 'src/services/api_client.dart';
import 'src/services/app_language.dart';
import 'src/services/socket_service.dart';

void main() {
  final api = ApiClient(baseUrl: 'http://159.75.25.168/api');
  final socket = SocketService(socketUrl: 'http://159.75.25.168');
  runApp(ChatApp(api: api, socket: socket));
}

class ChatApp extends StatefulWidget {
  const ChatApp({super.key, required this.api, required this.socket});

  final ApiClient api;
  final SocketService socket;

  @override
  State<ChatApp> createState() => _ChatAppState();
}

class _ChatAppState extends State<ChatApp> {
  late final AppLanguageController _language;

  @override
  void initState() {
    super.initState();
    _language = AppLanguageController(widget.api)..load();
  }

  @override
  void dispose() {
    _language.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppLanguageScope(
      controller: _language,
      child: MaterialApp(
        title: _language.strings.appName,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B87)),
          useMaterial3: true,
        ),
        home: LoginScreen(api: widget.api, socket: widget.socket),
      ),
    );
  }
}
