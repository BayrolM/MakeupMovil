import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Flow: email → code → reset → complete
  String _flowState = 'email';

  // Email step
  final _emailController = TextEditingController();
  final _emailFocus = FocusNode();
  String? _emailError;
  bool _isCheckingEmail = false;
  Timer? _emailDebounce;

  // Code step
  final _codeController = TextEditingController();
  String? _codeError;

  // Reset step
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  // General
  bool _isLoading = false;
  String? _generalError;
  String? _verifiedToken;

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocus.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _emailDebounce?.cancel();
    super.dispose();
  }

  // ── Email validation (real-time like web) ──────────────────

  void _checkEmailAvailability(String email) {
    _emailDebounce?.cancel();
    if (email.trim().isEmpty || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim())) {
      setState(() {
        _isCheckingEmail = false;
        _emailError = null;
      });
      return;
    }
    setState(() {
      _isCheckingEmail = true;
      _emailError = null;
    });
    _emailDebounce = Timer(const Duration(milliseconds: 800), () async {
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final exists = await auth.checkEmailExists(email.trim());
      if (!mounted) return;
      setState(() {
        _isCheckingEmail = false;
        _emailError = exists ? null : 'Correo no registrado';
      });
    });
  }

  // ── Step 1: Submit email ───────────────────────────────────

  Future<void> _submitEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _emailError = 'Email no válido');
      return;
    }

    // Check final: si el debounce no terminó, verificar ahora
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final exists = await auth.checkEmailExists(email);
    if (!exists) {
      setState(() => _emailError = 'Correo no registrado');
      return;
    }
    if (_emailError != null) return;

    setState(() {
      _isLoading = true;
      _generalError = null;
    });

    final error = await auth.forgotPassword(email);

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isLoading = false;
        _generalError = error;
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _flowState = 'code';
    });
  }

  // ── Step 2: Verify code ────────────────────────────────────

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _codeError = 'El código debe tener 6 dígitos');
      return;
    }

    setState(() {
      _isLoading = true;
      _codeError = null;
      _generalError = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final valid = await auth.verifyResetCode(_emailController.text.trim(), code);

    if (!mounted) return;

    if (!valid) {
      setState(() {
        _isLoading = false;
        _codeError = 'Código incorrecto o expirado';
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _verifiedToken = code;
      _flowState = 'reset';
    });
  }

  // ── Step 3: Reset password ─────────────────────────────────

  Future<void> _resetPassword() async {
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    // Validators handle all checks, just verify non-empty and match
    if (newPass.isEmpty || confirmPass.isEmpty || newPass != confirmPass) return;

    setState(() {
      _isLoading = true;
      _generalError = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final error = await auth.resetPassword(_verifiedToken!, newPass);

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isLoading = false;
        _generalError = error;
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _flowState = 'complete';
    });
  }

  // ── Builders ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            if (_flowState != 'email') {
              setState(() {
                if (_flowState == 'code') _flowState = 'email';
                if (_flowState == 'reset') _flowState = 'code';
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Image.asset('assets/images/logo_glamour.png', height: 80, errorBuilder: (_, __, ___) => const Icon(Icons.lock_reset, size: 60, color: AppTheme.deepRose)),
              ),
              const SizedBox(height: 24),
              if (_flowState == 'email') _buildEmailStep(),
              if (_flowState == 'code') _buildCodeStep(),
              if (_flowState == 'reset') _buildResetStep(),
              if (_flowState == 'complete') _buildCompleteStep(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recuperar contraseña', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.deepRose)),
          const SizedBox(height: 8),
          Text('Ingresa tu correo electrónico y te enviaremos un código de verificación.', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const SizedBox(height: 32),
          TextFormField(
            controller: _emailController,
            focusNode: _emailFocus,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            maxLength: 40,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onChanged: _checkEmailAvailability,
            onFieldSubmitted: (_) => _submitEmail(),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Requerido';
              if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())) return 'Email no válido';
              if (_emailError != null) return _emailError;
              return null;
            },
            decoration: InputDecoration(
              labelText: 'Correo Electrónico',
              counterText: '',
              prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.deepRose),
              suffixIcon: _isCheckingEmail
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.deepRose),
                      ),
                    )
                  : _emailError != null
                      ? const Icon(Icons.error_outline, color: Colors.red, size: 20)
                      : _emailController.text.isNotEmpty && _emailError == null && !_isCheckingEmail
                          ? const Icon(Icons.check_circle_outline, color: Colors.green, size: 20)
                          : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          if (_generalError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_generalError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: (_isLoading || _isCheckingEmail || _emailError != null || _emailController.text.trim().isEmpty) ? null : _submitEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.deepRose,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('ENVIAR CÓDIGO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Verificar código', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.deepRose)),
        const SizedBox(height: 8),
        Text('Ingresa el código de 6 dígitos que enviamos a ${_emailController.text}', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        const SizedBox(height: 32),
        TextFormField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: (_) => setState(() {}),
          validator: (v) {
            if (v == null || v.isEmpty) return null;
            if (v.length < 6) return 'Debe tener 6 dígitos';
            return null;
          },
          decoration: InputDecoration(
            labelText: 'Código de verificación',
            counterText: '',
            errorText: _codeError,
            prefixIcon: const Icon(Icons.pin_outlined, color: AppTheme.deepRose),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        if (_generalError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_generalError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: (_isLoading || _codeController.text.length < 6) ? null : _verifyCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.deepRose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('VERIFICAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: _isLoading ? null : () async {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              await auth.forgotPassword(_emailController.text.trim());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Código reenviado'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('Reenviar código', style: TextStyle(color: AppTheme.deepRose, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildResetStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Nueva contraseña', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.deepRose)),
        const SizedBox(height: 4),
        Text('Crea una contraseña segura', style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 24),
        TextFormField(
          controller: _newPasswordController,
          obscureText: _obscureNew,
          maxLength: 225,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Requerido';
            if (v.length < 8) return 'Mínimo 8 caracteres';
            if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Falta una mayúscula';
            if (!RegExp(r'[a-z]').hasMatch(v)) return 'Falta una minúscula';
            if (!RegExp(r'[0-9]').hasMatch(v)) return 'Falta un número';
            if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(v)) return 'Falta carácter especial';
            return null;
          },
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Contraseña',
            counterText: '',
            prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.deepRose),
            suffixIcon: IconButton(
              icon: Icon(_obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey),
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
            ),
          ),
        ),
        const SizedBox(height: 4),
        _buildPasswordHints(_newPasswordController.text),
        const SizedBox(height: 16),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirm,
          maxLength: 225,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Requerido';
            if (v != _newPasswordController.text) return 'Las contraseñas no coinciden';
            return null;
          },
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Confirmar Contraseña',
            counterText: '',
            prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.deepRose),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
        ),
        if (_generalError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_generalError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _resetPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.deepRose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('RESTABLECER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildCompleteStep() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.check_circle, color: Colors.green, size: 80),
        const SizedBox(height: 24),
        const Text('¡Contraseña actualizada!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.deepRose)),
        const SizedBox(height: 12),
        Text('Tu contraseña ha sido restablecida correctamente.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.deepRose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('IR AL LOGIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordHints(String pass) {
    final checks = [
      ('8+ caracteres', pass.length >= 8),
      ('Mayúscula', RegExp(r'[A-Z]').hasMatch(pass)),
      ('Minúscula', RegExp(r'[a-z]').hasMatch(pass)),
      ('Número', RegExp(r'[0-9]').hasMatch(pass)),
      ('Carácter especial', RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(pass)),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: checks.map((c) {
        final ok = c.$2;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ok ? Icons.check_circle : Icons.cancel, size: 14, color: ok ? Colors.green : Colors.red.shade300),
            const SizedBox(width: 2),
            Text(c.$1, style: TextStyle(fontSize: 11, color: ok ? Colors.green : Colors.grey.shade500)),
          ],
        );
      }).toList(),
    );
  }
}
