import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:privat_test/main.dart';

void main() {
  testWidgets('renders the hello world greeting', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.widgetWithText(AppBar, 'Hello World'), findsOneWidget);
    expect(find.text('Hello, World!'), findsOneWidget);
  });
}
