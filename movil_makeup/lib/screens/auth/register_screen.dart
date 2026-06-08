import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _currentStep = 1;
  final _totalSteps = 3;

  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();

  // Step 1: Identidad
  String _tipoDocumento = 'CC';
  final _documentoController = TextEditingController();
  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();

  // Step 2: Ubicación
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _ciudadController = TextEditingController();
  final _departamentoController = TextEditingController();
  final _direccionController = TextEditingController();

  // Step 3: Seguridad
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Step 4: Verificación
  final _codeController = TextEditingController();
  String _registeredEmail = '';

  @override
  void dispose() {
    _documentoController.dispose();
    _nombresController.dispose();
    _apellidosController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _ciudadController.dispose();
    _departamentoController.dispose();
    _direccionController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  // ── Navegación entre pasos ─────────────────────────────────

  void _nextStep() {
    if (_currentStep == 1) {
      if (!_formKey1.currentState!.validate()) return;
    } else if (_currentStep == 2) {
      if (!_formKey2.currentState!.validate()) return;
    } else if (_currentStep == 3) {
      if (!_formKey3.currentState!.validate()) {
        return;
      }
      _submitRegister();
      return;
    }
    setState(() => _currentStep++);
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  // ── Registro ───────────────────────────────────────────────

  Future<void> _submitRegister() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.register(
      nombres: _nombresController.text.trim(),
      apellidos: _apellidosController.text.trim(),
      email: _emailController.text.trim(),
      telefono: _telefonoController.text.trim(),
      password: _passwordController.text,
      documento: _documentoController.text.trim(),
      direccion: _direccionController.text.trim(),
      ciudad: _ciudadController.text.trim(),
      departamento: _departamentoController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _registeredEmail = _emailController.text.trim();
        _currentStep = 4;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Error al registrarse'), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating),
      );
    }
  }

  // ── Verificar código ───────────────────────────────────────

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El código debe tener 6 dígitos'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.verifyEmail(email: _registeredEmail, code: code);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Cuenta verificada! Bienvenido a Glamour ML'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/client-home', (_) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Código incorrecto'), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating),
      );
    }
  }

  // ── UI ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentStep == 4 ? 'Verificar Correo' : 'Crear Cuenta'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _prevStep),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF0F2), Colors.white]),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (_currentStep <= 3) ...[
                const SizedBox(height: 8),
                _buildStepIndicator(),
                const SizedBox(height: 8),
              ],
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _currentStep == 4 ? _buildVerificationStep() : _buildFormStep(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Indicador de pasos ─────────────────────────────────────

  Widget _buildStepIndicator() {
    final labels = ['Identidad', 'Ubicación', 'Seguridad'];
    return Row(
      children: List.generate(_totalSteps, (i) {
        final step = i + 1;
        final isActive = step <= _currentStep;
        final isCurrent = step == _currentStep;
        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (i > 0)
                    Expanded(
                      child: Container(height: 2, color: isActive ? AppTheme.deepRose : Colors.grey.shade300),
                    ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? AppTheme.deepRose : Colors.grey.shade300,
                      border: isCurrent ? Border.all(color: AppTheme.deepRose, width: 2) : null,
                    ),
                    child: Center(
                      child: step < _currentStep
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : Text('$step', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (i < _totalSteps - 1)
                    Expanded(
                      child: Container(height: 2, color: step < _currentStep ? AppTheme.deepRose : Colors.grey.shade300),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(labels[i], style: TextStyle(fontSize: 10, color: isActive ? AppTheme.deepRose : Colors.grey, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        );
      }),
    );
  }

  // ── Formulario por pasos ───────────────────────────────────

  Widget _buildFormStep() {
    switch (_currentStep) {
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      case 3:
        return _buildStep3();
      default:
        return const SizedBox.shrink();
    }
  }

  // Paso 1: Identidad
  Widget _buildStep1() {
    return Form(
      key: _formKey1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Identidad', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.deepRose)),
          const SizedBox(height: 4),
          Text('Cuéntanos sobre ti', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),

          DropdownButtonFormField<String>(
            initialValue: _tipoDocumento,
            decoration: const InputDecoration(labelText: 'Tipo de Documento', prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.deepRose)),
            items: const [
              DropdownMenuItem(value: 'CC', child: Text('Cédula de Ciudadanía')),
              DropdownMenuItem(value: 'TI', child: Text('Tarjeta de Identidad')),
              DropdownMenuItem(value: 'CE', child: Text('Cédula de Extranjería')),
              DropdownMenuItem(value: 'PAS', child: Text('Pasaporte')),
            ],
            onChanged: (v) => setState(() => _tipoDocumento = v ?? 'CC'),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _documentoController,
            keyboardType: _tipoDocumento == 'PAS' ? TextInputType.text : TextInputType.number,
            maxLength: 15,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            inputFormatters: _tipoDocumento == 'PAS'
                ? [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]'))]
                : [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Requerido';
              if (v.trim().length < 8) return 'Mínimo 8 caracteres';
              return null;
            },
            decoration: const InputDecoration(labelText: 'Número de Documento', prefixIcon: Icon(Icons.pin_outlined, color: AppTheme.deepRose), counterText: ''),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _nombresController,
            textCapitalization: TextCapitalization.words,
            maxLength: 30,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Requerido';
              if (v.trim().length < 2) return 'Mínimo 2 caracteres';
              return null;
            },
            decoration: const InputDecoration(labelText: 'Nombres', prefixIcon: Icon(Icons.person_outline, color: AppTheme.deepRose), counterText: ''),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _apellidosController,
            textCapitalization: TextCapitalization.words,
            maxLength: 30,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Requerido';
              if (v.trim().length < 2) return 'Mínimo 2 caracteres';
              return null;
            },
            decoration: const InputDecoration(labelText: 'Apellidos', prefixIcon: Icon(Icons.person_outline, color: AppTheme.deepRose), counterText: ''),
          ),
          const SizedBox(height: 32),

          _buildNextButton('Siguiente'),
        ],
      ),
    );
  }

  // Paso 2: Ubicación
  Widget _buildStep2() {
    return Form(
      key: _formKey2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Ubicación', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.deepRose)),
          const SizedBox(height: 4),
          Text('¿Dónde te enviamos tus compras?', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),

          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            maxLength: 40,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Requerido';
              if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())) return 'Email no válido';
              return null;
            },
            decoration: const InputDecoration(labelText: 'Correo Electrónico', prefixIcon: Icon(Icons.email_outlined, color: AppTheme.deepRose), counterText: ''),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _telefonoController,
            keyboardType: TextInputType.phone,
            maxLength: 20,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Requerido';
              if (v.trim().length < 10) return 'Mínimo 10 dígitos';
              return null;
            },
            decoration: const InputDecoration(labelText: 'Teléfono', prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.deepRose), counterText: ''),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _ciudadController,
            textCapitalization: TextCapitalization.words,
            maxLength: 50,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Requerido';
              if (v.trim().length < 3) return 'Mínimo 3 caracteres';
              return null;
            },
            decoration: const InputDecoration(labelText: 'Ciudad', prefixIcon: Icon(Icons.location_city, color: AppTheme.deepRose), counterText: ''),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _departamentoController,
            textCapitalization: TextCapitalization.words,
            maxLength: 50,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Requerido';
              if (v.trim().length < 3) return 'Mínimo 3 caracteres';
              return null;
            },
            decoration: const InputDecoration(labelText: 'Departamento', prefixIcon: Icon(Icons.map_outlined, color: AppTheme.deepRose), counterText: ''),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _direccionController,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 30,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Requerido';
              if (v.trim().length < 10) return 'Mínimo 10 caracteres';
              return null;
            },
            decoration: const InputDecoration(labelText: 'Dirección', prefixIcon: Icon(Icons.home_outlined, color: AppTheme.deepRose), counterText: ''),
          ),
          const SizedBox(height: 32),

          _buildNextButton('Siguiente'),
        ],
      ),
    );
  }

  // Paso 3: Seguridad
  Widget _buildStep3() {
    return Form(
      key: _formKey3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Seguridad', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.deepRose)),
          const SizedBox(height: 4),
          Text('Crea una contraseña segura', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),

          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
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
              prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.deepRose),
              counterText: '',
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 4),
          _buildPasswordHints(_passwordController.text),
          const SizedBox(height: 16),

          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            maxLength: 225,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Requerido';
              if (v != _passwordController.text) return 'Las contraseñas no coinciden';
              return null;
            },
            decoration: InputDecoration(
              labelText: 'Confirmar Contraseña',
              prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.deepRose),
              counterText: '',
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),
          const SizedBox(height: 32),

          _buildNextButton('Crear mi cuenta'),
        ],
      ),
    );
  }

  // ── Indicadores de fortaleza de contraseña ─────────────────

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

  // Paso 4: Verificación de correo
  Widget _buildVerificationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.mark_email_read_outlined, size: 64, color: AppTheme.deepRose),
        const SizedBox(height: 16),
        const Text('Verifica tu correo', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.deepRose)),
        const SizedBox(height: 8),
        Text('Enviamos un código de 6 dígitos a:', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(_registeredEmail, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 32),

        TextFormField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Requerido';
            if (v.length != 6) return 'Debe tener 6 dígitos';
            return null;
          },
          decoration: const InputDecoration(
            hintText: '000000',
            counterText: '',
            prefixIcon: Icon(Icons.vpn_key_outlined, color: AppTheme.deepRose),
          ),
        ),
        const SizedBox(height: 24),

        Provider.of<AuthProvider>(context).isLoading
            ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepRose)))
            : Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), gradient: const LinearGradient(colors: [AppTheme.deepRose, AppTheme.accentColor])),
                child: ElevatedButton(
                  onPressed: _verifyCode,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('VERIFICAR CUENTA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
              ),
        const SizedBox(height: 16),

        TextButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Revisa tu bandeja de entrada'), behavior: SnackBarBehavior.floating),
            );
          },
          child: const Text('¿No recibiste el código? Revisa tu correo'),
        ),
      ],
    );
  }

  // ── Botón siguiente / crear cuenta ─────────────────────────

  Widget _buildNextButton(String label) {
    final isLoading = Provider.of<AuthProvider>(context).isLoading;
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepRose)));
    }
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), gradient: const LinearGradient(colors: [AppTheme.deepRose, AppTheme.accentColor])),
      child: ElevatedButton(
        onPressed: _nextStep,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 16)),
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white)),
      ),
    );
  }
}
