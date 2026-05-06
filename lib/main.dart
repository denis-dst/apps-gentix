import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants.dart';
import 'providers/auth_provider.dart';
import 'providers/event_provider.dart';
import 'providers/gate_provider.dart';
import 'providers/pos_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/event_selection_screen.dart';

import 'providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settingsProvider = SettingsProvider();
  await settingsProvider.init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => settingsProvider,
      child: const GenTixApp(),
    ),
  );
}

class GenTixApp extends StatelessWidget {
  const GenTixApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(settings)),
        ChangeNotifierProvider(create: (_) => EventProvider(settings)),
        ChangeNotifierProvider(create: (_) => GateProvider(settings)),
        ChangeNotifierProvider(create: (_) => POSProvider(settings)),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppConstants.primaryColor,
            brightness: Brightness.dark,
            primary: AppConstants.primaryColor,
            secondary: AppConstants.secondaryColor,
            background: AppConstants.darkBg,
            surface: AppConstants.cardBg,
          ),
          scaffoldBackgroundColor: AppConstants.darkBg,
          textTheme: GoogleFonts.interTextTheme(
            ThemeData.dark().textTheme,
          ),
          cardTheme: CardThemeData(
            color: AppConstants.cardBg,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().checkAuth();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isAuthenticated) {
      return const EventSelectionScreen();
    }
    return const LoginScreen();
  }
}
