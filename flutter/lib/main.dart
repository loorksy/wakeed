import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/models.dart';
import 'screens/block_screen.dart';
import 'screens/home_screen.dart';
import 'screens/license_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'services/platform_service.dart';
import 'services/storage_service.dart';
import 'state/app_controller.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final storage = StorageService(prefs);
  final platform = PlatformService(storage);
  final api = ApiService(platform);
  final app = AppController(platform: platform, api: api);
  runApp(WakeedApp(controller: app));
  app.boot();
}

class WakeedApp extends StatelessWidget {
  const WakeedApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: controller,
      child: Consumer<AppController>(
        builder: (context, app, _) {
          return MaterialApp(
            title: 'وكيد — سند حوالة',
            debugShowCheckedModeBanner: false,
            theme: wakeedTheme(dark: false),
            darkTheme: wakeedTheme(dark: true),
            themeMode: app.themeMode,
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              return Directionality(
                textDirection: TextDirection.rtl,
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const _Gate(),
          );
        },
      ),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final phase = context.watch<AppController>().phase;
    return switch (phase) {
      AppPhase.boot => const Scaffold(body: Center(child: CircularProgressIndicator())),
      AppPhase.license => const LicenseScreen(),
      AppPhase.blocked => const BlockScreen(),
      AppPhase.login => const LoginScreen(),
      AppPhase.home => const HomeScreen(),
    };
  }
}
