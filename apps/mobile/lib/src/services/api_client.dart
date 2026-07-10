import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/chat_models.dart';

class ApiClient {
  ApiClient({required this.baseUrl});

  final String baseUrl;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> get token => _storage.read(key: 'accessToken');

  Future<void> logout() => _storage.delete(key: 'accessToken');

  Future<ChatUser> register(String identity, String password, String nickname) async {
    final data = await _post('/auth/register', {
      'identity': identity,
      'password': password,
      'nickname': nickname,
    });
    await _storage.write(key: 'accessToken', value: data['accessToken'] as String);
    return ChatUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<ChatUser> login(String identity, String password) async {
    final data = await _post('/auth/login', {'identity': identity, 'password': password});
    await _storage.write(key: 'accessToken', value: data['accessToken'] as String);
    return ChatUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<ChatUser> me() async {
    final data = await _get('/users/me') as Map<String, dynamic>;
    return ChatUser.fromJson(data);
  }

  Future<List<ChatUser>> searchUsers(String query) async {
    final data = await _get('/users/search?q=${Uri.encodeQueryComponent(query)}') as List<dynamic>;
    return data.map((item) => ChatUser.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ContactRelation> sendContactRequest(String userId) async {
    final data = await _post('/contacts', {'userId': userId});
    return ContactRelation.fromJson(data);
  }

  Future<List<ContactRelation>> contacts() async {
    final data = await _get('/contacts') as List<dynamic>;
    return data.map((item) => ContactRelation.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<ContactRelation>> incomingContactRequests() async {
    final data = await _get('/contacts/requests/incoming') as List<dynamic>;
    return data.map((item) => ContactRelation.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<ContactRelation>> outgoingContactRequests() async {
    final data = await _get('/contacts/requests/outgoing') as List<dynamic>;
    return data.map((item) => ContactRelation.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ContactRelation> acceptContactRequest(String contactId) async {
    final data = await _post('/contacts/$contactId/accept', {});
    return ContactRelation.fromJson(data);
  }

  Future<void> rejectContactRequest(String contactId) async {
    await _post('/contacts/$contactId/reject', {});
  }

  Future<Conversation> createDirectConversation(String userId) async {
    final data = await _post('/conversations/direct', {'userId': userId});
    return Conversation.fromJson(data);
  }

  Future<List<Conversation>> conversations() async {
    final data = await _get('/conversations') as List<dynamic>;
    return data.map((item) => Conversation.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<ChatMessage>> messages(String conversationId) async {
    final data = await _get('/messages/$conversationId') as List<dynamic>;
    return data.map((item) => ChatMessage.fromJson(item as Map<String, dynamic>)).toList().reversed.toList();
  }

  Future<ChatMessage> sendMessage(String conversationId, String type, String? content) async {
    final data = await _post('/messages', {
      'conversationId': conversationId,
      'type': type,
      'content': content,
    });
    return ChatMessage.fromJson(data);
  }

  Future<void> markConversationRead(String conversationId) async {
    await _post('/messages/$conversationId/read', {});
  }

  Future<Map<String, dynamic>> uploadFile(String type, File file) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/uploads/file?type=$type'));
    final accessToken = await token;
    if (accessToken != null) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decode(response) as Map<String, dynamic>;
  }

  Future<dynamic> _get(String path) async {
    final response = await http.get(Uri.parse('$baseUrl$path'), headers: await _headers());
    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _decode(response) as Map<String, dynamic>;
  }

  Future<Map<String, String>> _headers() async {
    final accessToken = await token;
    return {
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
  }

  dynamic _decode(http.Response response) {
    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body is Map ? body['message'] : 'Request failed');
    }
    return body;
  }
}
