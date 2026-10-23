import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();

  // ─── Mode: Sign In vs Sign Up ──────────────────────────────────
  bool _isSignUp = false;

  // ─── Controllers ───────────────────────────────────────────────
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // ─── State ──────────────────────────────────────────────────────
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ─── Submit Action (Sign In or Sign Up) ─────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isSignUp) {
        await AuthService.signUpWithEmailPassword(
          email: _emailController.text,
          password: _passwordController.text,
          displayName: _nameController.text,
        );
      } else {
        await AuthService.signInWithEmailPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AuthService.getErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  // ─── Guest / Demo Sign In ──────────────────────────────────────
  Future<void> _signInAsGuest() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.signInAnonymously();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AuthService.getErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  // ─── Forgot Password Dialog ────────────────────────────────────
  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Reset Password',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your email address and we will send you a password reset link.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'your.name@email.com',
                  prefixIcon: const Icon(Icons.email_outlined, size: 18, color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.secondary,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final email = resetEmailController.text.trim();
                if (email.isNotEmpty) {
                  Navigator.pop(ctx);
                  try {
                    await AuthService.sendPasswordReset(email);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Password reset link sent to $email'),
                          backgroundColor: AppColors.accent,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AuthService.getErrorMessage(e)),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Send Link'),
            ),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 1. App Logo & Brand Header
                  _buildBrandHeader(),

                  const SizedBox(height: 28),

                  // 2. Mode Switcher (Sign In vs Create Account)
                  _buildTabSwitcher(),

                  const SizedBox(height: 20),

                  // 3. Error Banner (if any)
                  if (_errorMessage != null) ...[
                    _buildErrorBanner(_errorMessage!),
                    const SizedBox(height: 16),
                  ],

                  // 4. Form Card
                  _buildFormCard(),

                  const SizedBox(height: 20),

                  // 5. Guest / Demo Option
                  _buildGuestButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BRAND HEADER
  // ═══════════════════════════════════════════════════════════════
  Widget _buildBrandHeader() {
    return Column(
      children: [
        // Cozy App Logo Badge
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Image.asset(
              'lib/image/book-icon.png',
              width: 52,
              height: 52,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'ReadJournal',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your cozy reading sanctuary & tracker',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB SWITCHER
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTabSwitcher() {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.divider.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_isSignUp) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _isSignUp = false;
                    _errorMessage = null;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: !_isSignUp ? AppColors.cardBackground : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: !_isSignUp
                      ? [
                          BoxShadow(
                            color: AppColors.textPrimary.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: !_isSignUp ? FontWeight.w700 : FontWeight.w500,
                      color: !_isSignUp ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_isSignUp) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _isSignUp = true;
                    _errorMessage = null;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _isSignUp ? AppColors.cardBackground : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: _isSignUp
                      ? [
                          BoxShadow(
                            color: AppColors.textPrimary.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: _isSignUp ? FontWeight.w700 : FontWeight.w500,
                      color: _isSignUp ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ERROR BANNER
  // ═══════════════════════════════════════════════════════════════
  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FORM CARD
  // ═══════════════════════════════════════════════════════════════
  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name field (Sign Up only)
            if (_isSignUp) ...[
              _buildInputLabel('Reader Name'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                decoration: _buildInputDecoration(
                  hint: 'e.g. June Reader',
                  icon: Icons.person_outline_rounded,
                ),
                validator: (val) {
                  if (_isSignUp && (val == null || val.trim().isEmpty)) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
            ],

            // Email field
            _buildInputLabel('Email Address'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: _buildInputDecoration(
                hint: 'your.name@email.com',
                icon: Icons.email_outlined,
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter your email';
                }
                if (!val.contains('@') || !val.contains('.')) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),

            const SizedBox(height: 14),

            // Password field
            _buildInputLabel('Password'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: _buildInputDecoration(
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'Please enter your password';
                }
                if (_isSignUp && val.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),

            // Confirm Password field (Sign Up only)
            if (_isSignUp) ...[
              const SizedBox(height: 14),
              _buildInputLabel('Confirm Password'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                decoration: _buildInputDecoration(
                  hint: '••••••••',
                  icon: Icons.lock_reset_rounded,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                validator: (val) {
                  if (_isSignUp) {
                    if (val == null || val.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (val != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                  }
                  return null;
                },
              ),
            ],

            // Forgot password (Sign In only)
            if (!_isSignUp) ...[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showForgotPasswordDialog,
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 20),
            ],

            const SizedBox(height: 6),

            // Submit Button
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: _isLoading ? null : _submit,
                  borderRadius: BorderRadius.circular(14),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isSignUp ? 'Create Account' : 'Sign In',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 13,
        color: AppColors.textSecondary.withValues(alpha: 0.5),
      ),
      prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.secondary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // GUEST BUTTON
  // ═══════════════════════════════════════════════════════════════
  Widget _buildGuestButton() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: AppColors.divider.withValues(alpha: 0.6))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                ),
              ),
            ),
            Expanded(child: Divider(color: AppColors.divider.withValues(alpha: 0.6))),
          ],
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _signInAsGuest,
          icon: const Icon(Icons.person_outline_rounded, size: 18),
          label: const Text('Continue as Guest'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.divider, width: 1.2),
            backgroundColor: AppColors.cardBackground,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
