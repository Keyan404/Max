import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'features/settings/settings_provider.dart';
import 'core/network/api_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with fallback error catches (prevents crashes if credentials are not yet set)
  try {
    // Under standard Flutter, this will search for the configuration file automatically.
    // We catch exceptions so that developers can run the app offline without Google services.
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization skipped or failed: $e");
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dynamically update ApiClient's base URL whenever settings are loaded/changed
    final settings = ref.watch(settingsProvider);
    ApiClient().baseUrl = "${settings.apiBaseUrl}/api";

    return MaterialApp.router(
      title: 'MAX AI OS',
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
