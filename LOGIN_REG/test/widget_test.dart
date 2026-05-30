// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:indoor_navigation/main.dart';
import 'package:indoor_navigation/supabase_config.dart';

void main() {
  testWidgets('Campus Navigator welcome screen smoke test', (WidgetTester tester) async {
    // Initialize Supabase for the test environment
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );

    // Build our app and trigger a frame.
    await tester.pumpWidget(const IndoorNavigationApp());

    // Verify that the welcome screen is loaded with the proper elements.
    expect(find.text('Campus Navigator'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });
}
