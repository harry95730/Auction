import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../teams/domain/entities/team.dart';
import '../../../users/domain/repositories/user_profile_repository.dart';
import '../widgets/dotted_background.dart';

/// Dark neon auth shell — email/password or Google, then syncs `users` + team link.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.userProfileRepository,
    this.onLoginSuccess,
    this.onRegister,
  });

  final UserProfileRepository userProfileRepository;
  /// Optional; auth state is also driven globally — can be empty.
  final VoidCallback? onLoginSuccess;
  final VoidCallback? onRegister;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _signingIn = false;

  static Future<void>? _googleInitFuture;

  Future<void> _ensureGoogleSignInReady() async {
    _googleInitFuture ??= GoogleSignIn.instance.initialize();
    await _googleInitFuture;
  }

  static const _bg = Color(0xFF0A0E14);
  static const _neon = Color(0xFF62FF62);
  static const _card = Color(0xFF161B22);
  static const _fieldFill = Color(0xFF21262D);

  static const _labelStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
    fontSize: 14,
  );
  static const _bodyStyle = TextStyle(
    color: Colors.white70,
    fontSize: 13,
    height: 1.4,
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Same synthetic email as [Team.registerTeam] / registration screen
  /// ([Team.firebaseAuthEmailFromTeamName]) when the user types a team name
  /// instead of a full address.
  String _resolveLoginEmail(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return t;
    if (t.contains('@')) return t;
    return Team.firebaseAuthEmailFromTeamName(t);
  }

  Future<void> _signIn() async {
    final rawLogin = _emailController.text.trim();
    final password = _passwordController.text;
    if (rawLogin.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter team name or email and password')),
      );
      return;
    }
    final email = _resolveLoginEmail(rawLogin);
    setState(() => _signingIn = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final u = cred.user;
      if (u != null) {
        try {
          await widget.userProfileRepository.syncUserDocumentAfterSignIn(u);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Profile sync issue: $e')),
            );
          }
        }
      }
      if (!mounted) return;
      widget.onLoginSuccess?.call();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Sign-in failed (${e.code})')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _signingIn = true);
    try {
      await _ensureGoogleSignInReady();
      final account = await GoogleSignIn.instance.authenticate();
      final auth = account.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
      );
      final cred = await FirebaseAuth.instance.signInWithCredential(credential);
      final u = cred.user;
      if (u != null) {
        try {
          await widget.userProfileRepository.syncUserDocumentAfterSignIn(u);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Profile sync issue: $e')),
            );
          }
        }
      }
      if (!mounted) return;
      widget.onLoginSuccess?.call();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in: ${e.description ?? e.code.name}')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Google sign-in failed (${e.code})')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const Positioned.fill(child: DottedBackground()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildAccessBlurb(),
                  const SizedBox(height: 24),
                  _buildRegisterLink(),
                  const SizedBox(height: 40),
                  _buildLoginForm(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AUCTION',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const Text(
          'COMMAND.',
          style: TextStyle(
            color: _neon,
            fontSize: 40,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Container(height: 3, width: 60, color: _neon),
      ],
    );
  }

  Widget _buildAccessBlurb() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildIconBox(Icons.vpn_key_outlined, Colors.amber.shade700),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CAPTAIN ACCESS', style: _labelStyle),
              SizedBox(height: 4),
              Text(
                'Email/password, or Google. Your profile is saved to Firestore; we link your squad if your Google email matches a player on a team.',
                style: _bodyStyle,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterLink() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NEW SQUAD?',
          style: _labelStyle.copyWith(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: _signingIn ? null : widget.onRegister,
          borderRadius: BorderRadius.circular(4),
          child: const Row(
            children: [
              Text(
                'Register your team',
                style: TextStyle(
                  color: _neon,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward, color: _neon, size: 18),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SIGN IN',
            style: TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 20),
          _customTextField(
            label: 'TEAM NAME OR EMAIL',
            hint: 'Mumbai Mavericks or mumbaimavericks@gmail.com',
            icon: Icons.alternate_email,
            controller: _emailController,
            keyboardType: TextInputType.text,
            obscure: false,
          ),
          _customTextField(
            label: 'PASSWORD',
            hint: '••••••••',
            icon: Icons.lock_outline,
            controller: _passwordController,
            obscure: _obscurePassword,
            onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _signingIn ? null : () {},
              child: Text(
                'Forgot password?',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildLoginButton(),
          const SizedBox(height: 16),
          _buildGoogleSignInButton(),
        ],
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: _signingIn ? null : _signInWithGoogle,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                'G',
                style: TextStyle(
                  color: Color(0xFF4285F4),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Sign in with Google',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _customTextField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required bool obscure,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onToggleObscure,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            enabled: !_signingIn,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              prefixIcon: Icon(icon, color: Colors.white24, size: 20),
              suffixIcon: onToggleObscure != null
                  ? IconButton(
                      onPressed: _signingIn ? null : onToggleObscure,
                      icon: Icon(
                        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: Colors.white38,
                        size: 20,
                      ),
                    )
                  : null,
              filled: true,
              fillColor: _fieldFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _signingIn ? null : _signIn,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          width: double.infinity,
          height: 55,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              colors: _signingIn
                  ? [Colors.grey.shade700, Colors.grey.shade800]
                  : const [_neon, Color(0xFF32CD32)],
            ),
            boxShadow: [
              if (!_signingIn)
                BoxShadow(
                  color: _neon.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_signingIn) ...[
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _neon.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                _signingIn ? 'SIGNING IN…' : 'LOG IN',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              if (!_signingIn) ...[
                const SizedBox(width: 8),
                Icon(Icons.login, color: Colors.black.withValues(alpha: 0.7)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconBox(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}
