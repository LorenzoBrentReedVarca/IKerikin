import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Shared visual frame for all authentication screens.
class AuthFrame extends StatelessWidget {
  const AuthFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBackButton = false,
  });
  final String title;
  final String subtitle;
  final Widget child;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: showBackButton
          ? AppBar(backgroundColor: Colors.transparent, elevation: 0)
          : null,
      body: Stack(
        children: [
          // Soft gradient wash behind the auth card gives depth without noise.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.primaryContainer.withValues(alpha: .55),
                    scheme.surface,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -60,
            child: _softBlob(240, scheme.tertiary.withValues(alpha: .22)),
          ),
          Positioned(
            top: 120,
            left: -80,
            child: _softBlob(200, scheme.primary.withValues(alpha: .18)),
          ),
          ResponsiveBody(
            maxWidth: 480,
            child: SingleChildScrollView(
              child: AnimatedAppear(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    const Center(child: _AnimatedAuthLogo()),
                    const SizedBox(height: 24),
                    if (showBackButton) ...[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.displaySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ] else ...[
                      const Center(child: BubbleWordmark(fontSize: 40)),
                      const SizedBox(height: 14),
                      Center(child: TaglinePill(text: subtitle)),
                    ],
                    const SizedBox(height: 30),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: child,
                      ),
                    ),
                    if (!AppConfig.hasSupabase) ...[
                      const SizedBox(height: 12),
                      Card(
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Icon(
                                Icons.offline_bolt_rounded,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onTertiaryContainer,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Preview mode: cloud sync and Google login are disabled.',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onTertiaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _softBlob(double size, Color color) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    ),
  );
}

/// Breathing IKeriKin logo mark used at the top of every auth screen. Falls
/// back to a static version when the user has requested reduced motion.
class _AnimatedAuthLogo extends StatefulWidget {
  const _AnimatedAuthLogo();

  @override
  State<_AnimatedAuthLogo> createState() => _AnimatedAuthLogoState();
}

class _AnimatedAuthLogoState extends State<_AnimatedAuthLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget mark(double glow) => Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient(context),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: .28 + .12 * glow),
            blurRadius: 28 + 6 * glow,
            spreadRadius: -4,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Icon(Icons.favorite_rounded, size: 48, color: Colors.white),
    );

    if (prefersReducedMotion(context)) return mark(0);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Transform.scale(scale: .96 + .04 * t, child: mark(t));
      },
    );
  }
}

/// Parent email and Google sign-in screen.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signIn(_email.text, _password.text);
      if (mounted) context.go('/home');
    } catch (error) {
      if (mounted) showMessage(context, error.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider);
    return AuthFrame(
      title: 'Welcome to IKeriKin',
      subtitle: 'I Care for Your Kin',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (value) => value != null && value.contains('@')
                  ? null
                  : 'Enter a valid email address',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) => (value?.length ?? 0) >= 6
                  ? null
                  : 'Password must have at least 6 characters',
              onFieldSubmitted: (_) => _signIn(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: busy ? null : () => context.push('/forgot-password'),
                child: const Text('Forgot password?'),
              ),
            ),
            FilledButton(
              onPressed: busy ? null : _signIn,
              child: busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sign in'),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      try {
                        await ref
                            .read(authControllerProvider.notifier)
                            .google();
                      } catch (error) {
                        if (context.mounted)
                          showMessage(context, error.toString(), error: true);
                      }
                    },
              icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
              label: const Text('Continue with Google'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: busy ? null : () => context.push('/register'),
              child: const Text('New to IKeriKin? Create an account'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Parent account registration screen with email verification.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _accepted = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider);
    return AuthFrame(
      title: 'Create your account',
      subtitle: 'Start personalized learning for your child.',
      showBackButton: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Parent name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) =>
                  (value?.trim().length ?? 0) >= 2 ? null : 'Enter your name',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (value) => value != null && value.contains('@')
                  ? null
                  : 'Enter a valid email',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                helperText: 'At least 8 characters',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (value) => (value?.length ?? 0) >= 8
                  ? null
                  : 'Use at least 8 characters',
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _accepted,
              onChanged: (value) => setState(() => _accepted = value ?? false),
              title: const Text('I agree to the Terms and Privacy Policy.'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: busy || !_accepted
                  ? null
                  : () async {
                      if (!_formKey.currentState!.validate()) return;
                      try {
                        await ref
                            .read(authControllerProvider.notifier)
                            .register(_name.text, _email.text, _password.text);
                        if (context.mounted)
                          context.go(
                            '/verify-email',
                            extra: _email.text.trim(),
                          );
                      } catch (error) {
                        if (context.mounted)
                          showMessage(context, error.toString(), error: true);
                      }
                    },
              child: const Text('Create account'),
            ),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Already have an account? Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Password recovery request screen.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthFrame(
    title: 'Reset your password',
    subtitle: 'We will email a secure reset link.',
    showBackButton: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email address',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () async {
            try {
              await ref
                  .read(authControllerProvider.notifier)
                  .resetPassword(_email.text);
              if (context.mounted)
                showMessage(
                  context,
                  'If that account exists, a reset link has been sent.',
                );
            } catch (error) {
              if (context.mounted)
                showMessage(context, error.toString(), error: true);
            }
          },
          child: const Text('Send reset link'),
        ),
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('Back to sign in'),
        ),
      ],
    ),
  );
}

/// Email verification guidance and resend screen.
class VerifyEmailScreen extends ConsumerWidget {
  const VerifyEmailScreen({super.key, required this.email});
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AuthFrame(
    title: 'Check your inbox',
    subtitle: 'A verification link was sent to $email.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.mark_email_read_rounded,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 18),
        const Text(
          'Open the link in the email to verify your address. You may then return to IKeriKin and sign in.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: () => context.go('/login'),
          child: const Text('Continue to sign in'),
        ),
        TextButton(
          onPressed: () async {
            try {
              await ref
                  .read(authControllerProvider.notifier)
                  .resendVerification(email);
              if (context.mounted)
                showMessage(context, 'Verification email sent again.');
            } catch (error) {
              if (context.mounted)
                showMessage(context, error.toString(), error: true);
            }
          },
          child: const Text('Resend email'),
        ),
      ],
    ),
  );
}
