import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

/// Sign-in page wired to the Cura Supabase backend.
///
/// Supports email/password (the same credentials as the iOS app) and Google
/// OAuth. Reflects auth state: once signed in it shows a confirmation instead
/// of the form.
class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _error;
  StreamSubscription<AuthState>? _authSub;

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    // Keep the page in sync with auth changes (e.g. returning from Google).
    _authSub = _supabase.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _supabase.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      // Session is set; the auth listener rebuilds into the signed-in view.
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _error = null);
    try {
      // On web this redirects the page to Google and back to the app origin.
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: Uri.base.origin,
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Google sign-in could not start.');
    }
  }

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _supabase.auth.currentUser;
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Back to home.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Back'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.mocha,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _Card(
                    child: user != null
                        ? _signedInView(user)
                        : _formView(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _signedInView(User user) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Icon(Icons.check_circle_rounded, color: AppColors.forest, size: 44),
        const SizedBox(height: 16),
        Text(
          'You\'re signed in',
          textAlign: TextAlign.center,
          style: GoogleFonts.fraunces(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: AppColors.warmBlack,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          user.email ?? 'Signed in',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 15, color: AppColors.mocha),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: () => context.go('/'),
          style: _primaryStyle(),
          child: _btnText('Back to home'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _signOut,
          style: TextButton.styleFrom(foregroundColor: AppColors.mocha),
          child: const Text('Sign out'),
        ),
      ],
    );
  }

  Widget _formView() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Welcome back',
            style: GoogleFonts.fraunces(
              fontSize: 34,
              fontWeight: FontWeight.w600,
              color: AppColors.warmBlack,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sign in to your Cura account.',
            style: GoogleFonts.inter(fontSize: 15, color: AppColors.mocha),
          ),
          const SizedBox(height: 28),

          // Google
          OutlinedButton.icon(
            onPressed: _loading ? null : _signInWithGoogle,
            icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
            label: _btnText('Continue with Google'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.warmBlack,
              side: BorderSide(color: AppColors.espresso.withValues(alpha: 0.25)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              const Expanded(child: Divider(color: Color(0x33000000))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.mocha),
                ),
              ),
              const Expanded(child: Divider(color: Color(0x33000000))),
            ],
          ),
          const SizedBox(height: 20),

          _label('Email'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const <String>[AutofillHints.email],
            decoration: _fieldDecoration('you@example.com'),
            validator: (String? v) {
              final String value = (v ?? '').trim();
              if (value.isEmpty) return 'Enter your email';
              if (!value.contains('@') || !value.contains('.')) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          _label('Password'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            autofillHints: const <String>[AutofillHints.password],
            onFieldSubmitted: (_) => _signInWithEmail(),
            decoration: _fieldDecoration('••••••••').copyWith(
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AppColors.mocha,
                  size: 20,
                ),
              ),
            ),
            validator: (String? v) {
              if ((v ?? '').isEmpty) return 'Enter your password';
              return null;
            },
          ),

          if (_error != null) ...<Widget>[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFB3261E).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.error_outline_rounded,
                      color: Color(0xFFB3261E), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFFB3261E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _signInWithEmail,
            style: _primaryStyle(),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.cream),
                    ),
                  )
                : _btnText('Sign in'),
          ),
        ],
      ),
    );
  }

  // ---- small style helpers ----

  ButtonStyle _primaryStyle() => FilledButton.styleFrom(
        backgroundColor: AppColors.forest,
        foregroundColor: AppColors.cream,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _btnText(String s) =>
      Text(s, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600));

  Widget _label(String s) => Text(
        s,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.espresso,
        ),
      );

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: AppColors.mocha.withValues(alpha: 0.5)),
        filled: true,
        fillColor: AppColors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.espresso.withValues(alpha: 0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.forest, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFB3261E)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFB3261E), width: 1.6),
        ),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.espresso.withValues(alpha: 0.08)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.espresso.withValues(alpha: 0.08),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}
