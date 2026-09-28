import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'app_settings.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'qr_scan_screen.dart';
import 'critical_stock_screen.dart';
import 'create_order_screen.dart';
import 'previous_orders_screen.dart';
import 'search_products_screen.dart';
import 'analytics_screen.dart';
import 'box_init_screen.dart';
import 'ai_insights_screen.dart';
import 'ai_assistant_screen.dart';
class AppColors {
  static const darkBlue = Color(0xFF061E29);
  static const midBlue = Color(0xFF1D546D);
  static const teal = Color(0xFF5F9598);
  static const light = Color(0xFFF3F4F4);
  static const danger = Color(0xFFE05C5C);
  static const success = Color(0xFF4CAF82);
  static const warning = Color(0xFFE8A44A);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await AppSettings.instance.load();

  runApp(const WarehouseApp());
}

class WarehouseApp extends StatelessWidget {
  const WarehouseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'StockIQ',
          debugShowCheckedModeBanner: false,
          themeMode: AppSettings.instance.themeMode,
          theme: _lightTheme(),
          darkTheme: _darkTheme(),
          initialRoute: '/login',
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/login':
                return _fadeRoute(const LoginScreen());

              case '/home':
                final args = settings.arguments as Map<String, dynamic>?;
                return _fadeRoute(
                  HomeScreen(
                    userName: args?['userName'] ?? 'Utilizator',
                    userRole: args?['userRole'] ?? 'Angajat · Depozit',
                  ),
                );

              case '/qr-scan':
                return _slideRoute(const QRScanScreen());

              case '/critical-stock':
                return _slideRoute(const CriticalStockScreen());

              case '/create-order':
                return _slideRoute(const CreateOrderScreen());

              case '/previous-orders':
                return _slideRoute(const PreviousOrdersScreen());

              case '/search-products':
                return _slideRoute(const SearchProductsScreen());

              case '/analytics':
                return _slideRoute(const AnalyticsScreen());

              case '/ai-insights':
                return _slideRoute(const AiInsightsScreen());
              case '/ai-assistant':
                return _slideRoute(const AiAssistantScreen());

              case '/my-orders':
                return _slideRoute(const PreviousOrdersScreen());

              case '/box-init':
                return _slideRoute(const BoxInitScreen());

              default:
                return _fadeRoute(const LoginScreen());
            }
          },
        );
      },
    );
  }

  static ThemeData _lightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.light,
      cardColor: Colors.white,
      primaryColor: AppColors.teal,
      dividerColor: AppColors.midBlue.withOpacity(0.14),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkBlue,
        elevation: 0,
        centerTitle: false,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Colors.white,
      ),
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: AppColors.darkBlue,
        displayColor: AppColors.darkBlue,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.darkBlue,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: TextStyle(
          color: AppColors.darkBlue.withOpacity(0.65),
        ),
        hintStyle: TextStyle(
          color: AppColors.darkBlue.withOpacity(0.40),
        ),
        prefixIconColor: AppColors.darkBlue.withOpacity(0.55),
        suffixIconColor: AppColors.darkBlue.withOpacity(0.55),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.midBlue.withOpacity(0.15),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.midBlue.withOpacity(0.15),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.teal,
            width: 1.4,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.teal;
          }
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.teal.withOpacity(0.35);
          }
          return Colors.grey.withOpacity(0.25);
        }),
      ),
    );
  }

  static ThemeData _darkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkBlue,
      cardColor: const Color(0xFF0F3244),
      primaryColor: AppColors.teal,
      dividerColor: AppColors.teal.withOpacity(0.18),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF08263A),
        foregroundColor: AppColors.light,
        elevation: 0,
        centerTitle: false,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Color(0xFF0A2838),
      ),
      textTheme: ThemeData.dark().textTheme.apply(
        bodyColor: AppColors.light,
        displayColor: AppColors.light,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.light,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0F3244),
        labelStyle: TextStyle(
          color: AppColors.light.withOpacity(0.70),
        ),
        hintStyle: TextStyle(
          color: AppColors.light.withOpacity(0.40),
        ),
        prefixIconColor: AppColors.light.withOpacity(0.55),
        suffixIconColor: AppColors.light.withOpacity(0.55),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.teal.withOpacity(0.18),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.teal.withOpacity(0.18),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.teal,
            width: 1.4,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.teal;
          }
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.teal.withOpacity(0.40);
          }
          return Colors.grey.withOpacity(0.25);
        }),
      ),
    );
  }

  static PageRoute _fadeRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    );
  }

  static PageRoute _slideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: FadeTransition(opacity: anim, child: child),
      ),
    );
  }
}