import 'package:flutter_test/flutter_test.dart';

import 'package:mwc_chat/main.dart';
import 'package:mwc_chat/src/services/api_client.dart';
import 'package:mwc_chat/src/services/socket_service.dart';

void main() {
  testWidgets('renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChatApp(
        api: ApiClient(baseUrl: 'http://localhost:3000/api'),
        socket: SocketService(socketUrl: 'http://localhost:3000'),
      ),
    );
    await tester.pump();

    expect(find.byType(ChatApp), findsOneWidget);
  });
}
