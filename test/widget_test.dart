// Basic widget test for NFC Field Logger app
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_field_logger/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const NfcFieldLoggerApp());

    // Verify that the app loads with proper navigation
    expect(find.byType(MaterialApp), findsOneWidget);
    
    // Verify main screen structure
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });
}
