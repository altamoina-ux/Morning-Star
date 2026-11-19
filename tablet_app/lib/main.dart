import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_controller.dart';
import 'core/preferences.dart';
import 'core/speech.dart';
import 'ui/auth_pages.dart';
import 'ui/common.dart';
import 'ui/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  final preferences = await SharedPreferences.getInstance();
  final controller = AppController(AppPreferences(preferences), SpeechOutput());
  runApp(QimingTablet(controller: controller));
  controller.initialize();
}

class QimingTablet extends StatelessWidget {
  const QimingTablet({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '启明帽 · 平板端',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xff0b1525),
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        primary: accent,
        surface: surface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xff0c192b),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ),
    home: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.loading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(semanticsLabel: '正在恢复本地设置'),
            ),
          );
        }
        if (controller.api == null) return ConnectPage(app: controller);
        if (!controller.loggedIn) return LoginPage(app: controller);
        return HomeShell(app: controller);
      },
    ),
  );
}
