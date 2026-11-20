import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lifemaxxing/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const _rememberKey = 'remember_email_enabled';
  static const _emailKey = 'remembered_email';
  static const _ink = Color(0xFF111111);
  static const _fieldBorder = Color(0xFFD9DDE3);
  static const _muted = Color(0xFF6B7280);

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();

  bool _isLogin = true;
  bool _loading = false;
  bool _consent = false;
  bool _remember = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRemembered();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _loadRemembered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool(_rememberKey) ?? false;
      final email = prefs.getString(_emailKey) ?? '';
      if (!mounted) return;
      setState(() {
        _remember = remember;
        if (remember) _email.text = email;
      });
    } catch (_) {}
  }

  Future<void> _saveRemembered(bool remember, String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_rememberKey, remember);
      if (remember) {
        await prefs.setString(_emailKey, email);
      } else {
        await prefs.remove(_emailKey);
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isLogin && !_consent) {
      setState(
          () => _error = 'Please agree to the privacy notice to register.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isLogin) {
        await _saveRemembered(_remember, _email.text.trim());
        await _auth.signIn(
            email: _email.text.trim(), password: _password.text);
      } else {
        await _auth.register(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _message(e.code));
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() =>
          _error = 'Enter your email above first, then tap Forgot password.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() => _error = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('If an account exists for $email, a reset email has been sent.'),
      ));
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _message(e.code));
    }
  }

  String _message(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return 'Authentication failed ($code).';
    }
  }

  void _showPrivacy() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Privacy notice'),
        content: const SingleChildScrollView(
          child: Text(
            'LifeMaxxing stores the tasks, assignments, habits, health logs and '
            'spending records that you enter, together with your name and email. '
            'Your data is kept in your private account, and only you can read it.\n\n'
            'To create AI insights, a summary of your last 7 days is sent to '
            "Google's Gemini service. Google's terms for this service may allow "
            'submitted content to be used to improve its products, so please do '
            'not enter sensitive real information while testing.\n\n'
            'Insights are suggestions only, not medical or financial advice. '
            'You can delete your account and all data at any time from the '
            'Profile screen.',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
        ],
      ),
    );
  }

  // ----------------------------- UI helpers -----------------------------

  InputDecoration _decoration(String hint, {Widget? suffix}) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
      suffixIcon: suffix,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: border(_fieldBorder),
      focusedBorder: border(_ink, 1.2),
      errorBorder: border(Colors.red.shade600),
      focusedErrorBorder: border(Colors.red.shade600, 1.2),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: _ink)),
      );

  Widget _checkbox(bool value, ValueChanged<bool?> onChanged) => SizedBox(
        width: 24,
        height: 24,
        child: Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: _ink,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          side: const BorderSide(color: Color(0xFF9CA3AF), width: 1.2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isLogin
                          ? 'Hi there, ready for success champ?'
                          : 'Create your account',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (!_isLogin) ...[
                      _label('Name*'),
                      TextFormField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        decoration: _decoration('Your name'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter your name'
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _label('Email*'),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration('email@example.com'),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Enter a valid email'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _label('Password*'),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!_loading) _submit();
                      },
                      decoration: _decoration(
                        '••••••••••',
                        suffix: IconButton(
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: _muted,
                          ),
                          onPressed: () =>
                              setState(() => _hidePassword = !_hidePassword),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'At least 6 characters'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    if (_isLogin)
                      Row(
                        children: [
                          _checkbox(_remember,
                              (v) => setState(() => _remember = v ?? false)),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _remember = !_remember),
                            child: const Text('Remember me',
                                style: TextStyle(fontSize: 13, color: _ink)),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _loading ? null : _forgotPassword,
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _ink,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: _checkbox(_consent,
                                    (v) => setState(() => _consent = v ?? false)),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'I agree to my data being collected and used to provide LifeMaxxing features.',
                                  style: TextStyle(fontSize: 13, color: _ink),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: _showPrivacy,
                            child: const Padding(
                              padding: EdgeInsets.only(left: 32, top: 4),
                              child: Text(
                                'Read privacy notice',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _ink,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        style: TextStyle(
                            color: Colors.red.shade700, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _ink,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF3A3A3A),
                          disabledForegroundColor: Colors.white70,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                _isLogin ? 'Log in' : 'Register',
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _loading
                            ? null
                            : () => setState(() {
                                  _isLogin = !_isLogin;
                                  _error = null;
                                }),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text.rich(
                            TextSpan(
                              text: _isLogin
                                  ? "Don't have an account? "
                                  : 'Already have an account? ',
                              style: const TextStyle(
                                  fontSize: 13, color: _muted),
                              children: [
                                TextSpan(
                                  text: _isLogin ? 'Signup' : 'Log in',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}