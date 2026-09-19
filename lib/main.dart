import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'data/supabase_client.dart';
import 'providers/profile_provider.dart';
import 'screens/home_screen.dart';
import 'screens/profile_select_screen.dart';
import 'widgets/nosflix_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await SupabaseInit.init();
  runApp(const ProviderScope(child: NosflixApp()));
}

class NosflixApp extends ConsumerWidget {
  const NosflixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);
    final profile = profileState.profile ?? Profile.leticia;

    return MaterialApp(
      title: 'Nosflix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(profile),
      home: profileState.loading
          ? const _SplashScreen()
          : (profileState.profile == null ? const ProfileSelectScreen() : const HomeScreen()),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: AppBackground(
        child: Center(child: Wordmark(size: 56)),
      ),
    );
  }
}
