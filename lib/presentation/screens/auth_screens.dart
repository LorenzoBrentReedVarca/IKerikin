import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../application/providers.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Shared visual frame for all authentication screens, styled after
/// Kombai's "calm centered form" concept and tuned for phones and tablets
/// (a single scaling column rather than a desktop split layout).
class AuthFrame extends StatelessWidget {
  const AuthFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBackButton = false,
    this.eyebrow,
    this.intro,
    this.footNote,
  });
  final String title;
  final String subtitle;
  final Widget child;
  final bool showBackButton;

  /// Small uppercase kicker shown above the card heading, e.g. "A calm
  /// place to begin".
  final String? eyebrow;

  /// Short supporting line shown inside the card, above the form fields.
  final String? intro;

  /// Gentle closing caption printed under the card.
  final String? footNote;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= 700;
    final cardMaxWidth = isTablet ? 560.0 : 440.0;
    final cardPadding = isTablet ? 32.0 : 22.0;

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
            maxWidth: cardMaxWidth,
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 28 : 18,
              vertical: 20,
            ),
            child: SingleChildScrollView(
              child: AnimatedAppear(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: isTablet ? 52 : 36),
                    Center(child: _AnimatedAuthLogo(size: isTablet ? 108 : 92)),
                    const SizedBox(height: 22),
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
                      Center(
                        child: BubbleWordmark(fontSize: isTablet ? 46 : 40),
                      ),
                      const SizedBox(height: 14),
                      Center(child: TaglinePill(text: subtitle)),
                    ],
                    const SizedBox(height: 20),
                    Center(
                      child: Container(
                        width: 180,
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.brandViolet,
                              AppTheme.brandPink,
                              AppTheme.brandCoral,
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: isTablet ? 32 : 24),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            height: 4,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.brandViolet,
                                  AppTheme.brandPink,
                                  AppTheme.brandCoral,
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              cardPadding,
                              cardPadding,
                              cardPadding,
                              cardPadding - 4,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (eyebrow != null) ...[
                                  Text(
                                    eyebrow!.toUpperCase(),
                                    style: const TextStyle(
                                      color: AppTheme.brandViolet,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.6,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                if (intro != null) ...[
                                  Text(
                                    intro!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                                child,
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (footNote != null) ...[
                      const SizedBox(height: 18),
                      Center(
                        child: Text(
                          footNote!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                    SizedBox(height: isTablet ? 32 : 20),
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
  const _AnimatedAuthLogo({this.size = 92});
  final double size;

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
    final radius = widget.size * .26;
    Widget mark(double glow) => Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: .28 + .12 * glow),
            blurRadius: 28 + 6 * glow,
            spreadRadius: -4,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset('assets/branding/app_icon.png', fit: BoxFit.cover),
      ),
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
    } on AuthException catch (error) {
      if (!mounted) return;
      if (error.code == 'email_not_confirmed') {
        context.push('/verify-email', extra: _email.text.trim());
      } else {
        showMessage(context, error.message, error: true);
      }
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
      eyebrow: 'A calm place to begin',
      intro: 'Sign in to continue learning with your child.',
      footNote: 'Made with care in the Philippines',
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
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Sign in'),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
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
      eyebrow: 'Parent account',
      footNote:
          'Your child’s learning space starts with one small, caring step.',
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
            const SizedBox(height: 6),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: CheckboxListTile(
                value: _accepted,
                onChanged: (value) =>
                    setState(() => _accepted = value ?? false),
                title: const Text('I agree to the Terms and Privacy Policy.'),
                controlAffinity: ListTileControlAffinity.leading,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
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
                      } on AuthException catch (error) {
                        if (context.mounted)
                          showMessage(context, error.message, error: true);
                      } catch (error) {
                        if (context.mounted)
                          showMessage(context, error.toString(), error: true);
                      }
                    },
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Create account'),
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
    eyebrow: 'Account recovery',
    footNote: 'Password reset starts with your email address.',
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
            } on AuthException catch (error) {
              if (context.mounted)
                showMessage(context, error.message, error: true);
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
    eyebrow: 'Almost there',
    footNote: 'Made with care in the Philippines',
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
            } on AuthException catch (error) {
              if (context.mounted)
                showMessage(context, error.message, error: true);
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
