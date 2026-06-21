import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../core/api.dart';
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/branded_splash.dart';
import '../widgets/pressable_scale.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _nameC = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _emailC.dispose();
    _passC.dispose();
    _nameC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailC.text.trim();
    final pass = _passC.text;
    final name = _nameC.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }
    if (_tabs.index == 1 && name.isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      final auth = ref.read(authProvider.notifier);
      if (_tabs.index == 0) {
        await auth.login(email, pass);
      } else {
        await auth.register(name, email, pass);
      }
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    Widget buildForm() {
      return AppCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabs,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor:
                    Theme.of(context).textTheme.bodyMedium?.color,
                tabs: const [
                  Tab(text: 'Sign In'),
                  Tab(text: 'Create Account'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _tabs.index == 1
                  ? Column(children: [
                      TextField(
                        controller: _nameC,
                        decoration: const InputDecoration(
                          hintText: 'Full name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                    ])
                  : const SizedBox.shrink(),
            ),

            TextField(
              controller: _emailC,
              decoration: const InputDecoration(
                hintText: 'Email address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passC,
              decoration: InputDecoration(
                hintText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),

            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: cs.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: cs.error, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),
            PressableScale(
              onTap: _loading ? null : _submit,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_tabs.index == 0 ? 'Sign In' : 'Create Account'),
              ),
            ),
          ],
        ),
      );
    }

    final form = buildForm();
    final animatedForm = disableAnimations
        ? form
        : form
            .animate()
            .fadeIn(duration: 400.ms, delay: 200.ms)
            .slideY(begin: 0.06, duration: 400.ms, delay: 200.ms);

    return Scaffold(
      body: AppScaffoldBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 24),
                  Image.asset(
                    'assets/branding/logo_full.png',
                    height: kSplashLogoHeight,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.receipt_long,
                      size: 48,
                      color: cs.primary,
                    ),
                  )
                      .animate(autoPlay: !disableAnimations)
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: -0.1, duration: 400.ms),
                  const SizedBox(height: 12),
                  Text(
                    'Track every rupee, every day.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                      .animate(autoPlay: !disableAnimations)
                      .fadeIn(duration: 350.ms, delay: 100.ms),
                  const SizedBox(height: AppSpacing.xl),
                  animatedForm,
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
