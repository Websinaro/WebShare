import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:webshare/main.dart';

void main() {
  testWidgets('Home screen shows Send and Receive actions', (WidgetTester tester) async {
    await tester.pumpWidget(const WebShareApp());

    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Receive'), findsOneWidget);
  });
}
