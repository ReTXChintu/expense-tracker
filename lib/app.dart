import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models.dart';
import 'providers.dart';
import 'theme.dart';
import 'screens/login.dart';
import 'screens/shell.dart';
import 'widgets/branded_splash.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    // Drop Android 12 system splash (launcher icon) as soon as Flutter paints.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
      _bootstrapSession();
    });
    _hideSplash();
  }

  void _bootstrapSession() {
    if (!ref.read(isLoggedInProvider)) return;
    // Clear stale provider errors from a prior failed auth read.
    ref.invalidate(categoriesProvider);
    ref.invalidate(paymentInstrumentsProvider);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data =
          await ref.read(apiProvider).get('/users/me') as Map<String, dynamic>;
      if (mounted) {
        ref.read(userProvider.notifier).state = User.fromJson(data);
      }
    } catch (_) {}
  }

  Future<void> _hideSplash() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(isLoggedInProvider);
    return MaterialApp(
      title: 'SpendLog',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            if (child != null) child,
            if (_showSplash) const BrandedSplashOverlay(),
          ],
        );
      },
      home: loggedIn ? const MainShell() : const LoginScreen(),
    );
  }
}
