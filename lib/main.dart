import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/constants/colors.dart';
import 'core/theme/app_theme.dart';
import 'core/supabase/supabase_config.dart';
import 'core/services/new_trip_alert.dart';
import 'core/services/motivation_notifications.dart';
import 'core/services/push_notifications.dart';
import 'providers/app_state_provider.dart';
import 'features/onboarding/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  await NewTripAlert.initialize();
  await MotivationNotifications.initialize();
  await PushNotifications.initialize();
  // Gold status bar matching the app's brand color, instead of the
  // platform default - AppBarTheme.systemOverlayStyle keeps this in sync
  // on screens with their own AppBar, which would otherwise reset it.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppColors.primary,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AppStateProvider())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'الهدهد',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,

      // Arabic RTL Localization configuration
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', ''), // Arabic
      ],
      locale: const Locale('ar', ''), // Set Arabic as default language

      home: const SplashScreen(),
    );
  }
}
