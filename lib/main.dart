import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/constants/colors.dart';
import 'core/theme/app_theme.dart';
import 'core/supabase/supabase_config.dart';
import 'core/services/new_trip_alert.dart';
import 'core/services/push_notifications.dart';
import 'l10n/generated/app_localizations.dart';
import 'providers/app_state_provider.dart';
import 'features/onboarding/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  await NewTripAlert.initialize();
  final appState = AppStateProvider();
  // Reads the captain's saved language choice before the first frame, so
  // the UI never flashes Arabic then jumps to French (or vice versa).
  await appState.loadSavedLocale();
  // Daily morning/evening motivational messages moved server-side (see
  // supabase/functions/send-motivation-push) - the client-scheduled
  // version (flutter_local_notifications zonedSchedule) silently stopped
  // firing after a device reboot or an OEM battery manager force-stopping
  // the app, with no way for the app to detect or recover from either.
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
      providers: [ChangeNotifierProvider.value(value: appState)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppStateProvider>().locale;
    return MaterialApp(
      title: 'الهدهد',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,

      // AppLocalizations.delegate covers the app's own Arabic/French
      // strings (see lib/l10n) - the Global*Localizations delegates below
      // only translate Flutter's own built-in widget labels (date pickers,
      // "OK"/"Cancel", etc.), a separate concern.
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,

      home: const SplashScreen(),
    );
  }
}
