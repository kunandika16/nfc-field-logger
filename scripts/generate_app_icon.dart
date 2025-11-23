import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Create the NFC icon widget
  final iconWidget = Container(
    width: 1024,
    height: 1024,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF2196F3), // Primary blue
          Color(0xFF1976D2), // Darker blue
        ],
      ),
      borderRadius: BorderRadius.circular(180), // Rounded corners like modern icons
    ),
    child: Center(
      child: Container(
        width: 600,
        height: 600,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.contactless,
          size: 400,
          color: Colors.white,
        ),
      ),
    ),
  );

  print('NFC App Icon generated successfully!');
  print('Please use this widget to create your app icon:');
  print('1. Run this widget in a Flutter app');
  print('2. Take a screenshot or export as PNG');
  print('3. Save as nfc_icon.png in assets/icon/');
}

class NfcIconWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.grey.shade200,
        body: Center(
          child: Container(
            width: 512,
            height: 512,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2196F3), // Primary blue
                  Color(0xFF1976D2), // Darker blue
                ],
              ),
              borderRadius: BorderRadius.circular(90), // Rounded corners
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.contactless,
                  size: 200,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}