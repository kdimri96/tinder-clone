import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/auth_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _loadingProvider;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        final destination = auth.isProfileComplete ? '/home' : '/complete-profile';
        Navigator.pushReplacementNamed(context, destination);
      } else {
        _showError(auth.error ?? 'Login failed');
      }
    }
  }

  Future<void> _handleSocialLogin(String provider) async {
    setState(() => _loadingProvider = provider);
    final auth = context.read<AuthProvider>();
    bool success = false;

    switch (provider) {
      case 'google':
        success = await auth.loginWithGoogle();
        break;
      case 'facebook':
        success = await auth.loginWithFacebook();
        break;
      case 'apple':
        success = await auth.loginWithApple();
        break;
    }

    if (!mounted) return;
    setState(() => _loadingProvider = null);

    if (success) {
      final destination = auth.isProfileComplete ? '/home' : '/complete-profile';
      Navigator.pushReplacementNamed(context, destination);
    } else if (auth.error != null) {
      _showError(auth.error!);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFormFields(),
                    const SizedBox(height: 28),
                    _buildLoginButton(),
                    const SizedBox(height: 32),
                    _buildSocialDivider(),
                    const SizedBox(height: 24),
                    _buildSocialButtons(),
                    const SizedBox(height: 32),
                    _buildSignUpLink(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 32),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Icon(Icons.local_fire_department, color: Colors.white, size: 40),
              const SizedBox(height: 10),
              const Text(
                'Welcome Back',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sign in to continue',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        StyledField(
          controller: _emailController,
          label: 'Email',
          hint: 'you@example.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null,
        ),
        const SizedBox(height: 16),
        StyledField(
          controller: _passwordController,
          label: 'Password',
          hint: '••••••••',
          icon: Icons.lock_outline,
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.grey,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          validator: (v) => v == null || v.length < 6 ? 'Password too short' : null,
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text(
                'Sign In',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }

  Widget _buildSocialDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFDEDEDE), thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or continue with',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFDEDEDE), thickness: 1)),
      ],
    );
  }

  Widget _buildSocialButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        CircleSocialButton(
          icon: const FaIcon(FontAwesomeIcons.google, size: 20, color: Color(0xFFDB4437)),
          label: 'Google',
          isLoading: _loadingProvider == 'google',
          onPressed: () => _handleSocialLogin('google'),
        ),
        CircleSocialButton(
          icon: const FaIcon(FontAwesomeIcons.facebook, size: 20, color: Color(0xFF1877F2)),
          label: 'Facebook',
          isLoading: _loadingProvider == 'facebook',
          onPressed: () => _handleSocialLogin('facebook'),
        ),
        CircleSocialButton(
          icon: const FaIcon(FontAwesomeIcons.apple, size: 22, color: Colors.black),
          label: 'Apple',
          isLoading: _loadingProvider == 'apple',
          onPressed: () => _handleSocialLogin('apple'),
        ),
      ],
    );
  }

  Widget _buildSignUpLink() {
    return Center(
      child: GestureDetector(
        onTap: () => Navigator.pushReplacementNamed(context, '/register'),
        child: RichText(
          text: TextSpan(
            text: "Don't have an account?  ",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
            children: [
              TextSpan(
                text: 'Sign Up',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
