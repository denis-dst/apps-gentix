import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'GenTix Scann Apps';
  static const String onlineApiUrl = 'https://sekelik-news.com/gentix-apps/api';
  static const String localApiUrl = 'http://192.168.202.253/gentix-apps/api';
  static const String apiBaseUrl = localApiUrl; // Default to local as previously requested
  
  // Colors
  static const Color primaryColor = Color(0xFF6366F1);
  static const Color secondaryColor = Color(0xFFEC4899);
  static const Color darkBg = Color(0xFF0F172A);
  static const Color cardBg = Color(0xFF1E293B);
  static const Color successColor = Color(0xFF22C55E);
  static const Color errorColor = Color(0xFFEF4444);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, Color(0xFF818CF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    colors: [secondaryColor, Color(0xFFF472B6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
