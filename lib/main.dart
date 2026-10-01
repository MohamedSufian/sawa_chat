import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/providers/core_providers.dart';
import 'features/notifications/push_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Without config the app can't reach Supabase; say so instead of crashing to a blank screen.
  if (!Env.isConfigured) {
    debugPrint(Env.setupHint);
    runApp(const _MissingConfigApp());
    return;
  }

  final (_, prefs, _) = await (
    Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabasePublishableKey),
    SharedPreferences.getInstance(),
    PushSetup.init(),
  ).wait;

  runApp(ProviderScope(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)], child: const SawaApp()));
}

/// Developer-facing screen, shown only when the build is missing `--dart-define-from-file=env.json`.
class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.settings_suggest_outlined, size: 48),
                const SizedBox(height: 16),
                Text('Supabase config missing', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                const SelectableText(Env.setupHint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
