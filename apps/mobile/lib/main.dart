import 'package:flutter/material.dart';
import 'src/screens/login_screen.dart';
import 'src/services/api_client.dart';
import 'src/services/socket_service.dart';

void main() {
  final api = ApiClient(baseUrl: 'http://159.75.25.168/api');
  final socket = SocketService(socketUrl: 'http://159.75.25.168');
  runApp(ChatApp(api: api, socket: socket));
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key, required this.api, required this.socket});

  final ApiClient api;
  final SocketService socket;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MWC Chat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B87)),
        useMaterial3: true,
      ),
      home: LoginScreen(api: api, socket: socket),
    );
  }
}
