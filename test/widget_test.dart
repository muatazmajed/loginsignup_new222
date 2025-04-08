// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loginsignup_new/main.dart';

void main() {
  testWidgets('Welcome screen test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp(showWelcomeScreen: true));

    // Verify that the welcome screen appears
    expect(find.text('مرحباً بك في تطبيق إدارة المشتركين'), findsOneWidget);
    expect(find.text('فترة تجريبية مجانية'), findsOneWidget);
    
    // You can add more test expectations here
  });
}