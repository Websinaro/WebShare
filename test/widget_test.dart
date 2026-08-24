// Basic smoke test: the app boots and shows the Home screen's primary actions.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:webshare/main.dart';

void main() {
  testWidgets('Home screen shows Send and Receive actions', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: WebShareApp()));
    await tester.pumpAndSettle();

    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Receive'), findsOneWidget);
  });
}
