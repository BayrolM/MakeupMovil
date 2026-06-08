import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  bool _initialized = false;

  late TextEditingController _nombresCtrl;
  late TextEditingController _apellidosCtrl;
  late TextEditingController _telefonoCtrl;
  late TextEditingController _direccionCtrl;
  late TextEditingController _ciudadCtrl;
  late TextEditingController _departamentoCtrl;

  String? errorNombres;
  String? errorApellidos;
  String? errorTelefono;
  String? errorDireccion;
  String? errorCiudad;
  String? errorDepartamento;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final profile = Provider.of<AuthProvider>(context, listen: false).userProfile;
      _nombresCtrl = TextEditingController(text: profile?['nombres'] ?? '');
      _apellidosCtrl = TextEditingController(text: profile?['apellidos'] ?? '');
      _telefonoCtrl = TextEditingController(text: profile?['telefono'] ?? '');
      _direccionCtrl = TextEditingController(text: profile?['direccion'] ?? '');
      _ciudadCtrl = TextEditingController(text: profile?['ciudad'] ?? '');
      _departamentoCtrl = TextEditingController(text: profile?['departamento'] ?? '');
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nombresCtrl.dispose();
    _apellidosCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    _ciudadCtrl.dispose();
    _departamentoCtrl.dispose();
    super.dispose();
  }

  // ── Validadores en vivo ──

  void _validateNombres(String val) {
    final v = val.trim();
    if (v.isEmpty) {
      errorNombres = 'Los nombres son obligatorios';
    } else if (v.length < 2) {
      errorNombres = 'Mínimo 2 caracteres';
    } else if (v.length > 30) {
      errorNombres = 'Máximo 30 caracteres';
    } else {
      errorNombres = null;
    }
  }

  void _validateApellidos(String val) {
    final v = val.trim();
    if (v.isEmpty) {
      errorApellidos = 'Los apellidos son obligatorios';
    } else if (v.length < 2) {
      errorApellidos = 'Mínimo 2 caracteres';
    } else if (v.length > 30) {
      errorApellidos = 'Máximo 30 caracteres';
    } else {
      errorApellidos = null;
    }
  }

  void _validateTelefono(String val) {
    final v = val.trim();
    if (v.isEmpty) {
      errorTelefono = 'El teléfono es obligatorio';
    } else if (v.length < 10) {
      errorTelefono = 'Mínimo 10 dígitos';
    } else if (v.length > 15) {
      errorTelefono = 'Máximo 15 dígitos';
    } else {
      errorTelefono = null;
    }
  }

  void _validateDireccion(String val) {
    final v = val.trim();
    if (v.isEmpty) {
      errorDireccion = 'La dirección es obligatoria';
    } else if (v.length < 3) {
      errorDireccion = 'Mínimo 3 caracteres';
    } else if (v.length > 40) {
      errorDireccion = 'Máximo 40 caracteres';
    } else {
      errorDireccion = null;
    }
  }

  void _validateCiudad(String val) {
    final v = val.trim();
    if (v.isEmpty) {
      errorCiudad = 'La ciudad es obligatoria';
    } else if (v.length < 3) {
      errorCiudad = 'Mínimo 3 caracteres';
    } else if (v.length > 50) {
      errorCiudad = 'Máximo 50 caracteres';
    } else {
      errorCiudad = null;
    }
  }

  void _validateDepartamento(String val) {
    final v = val.trim();
    if (v.isEmpty) {
      errorDepartamento = 'El departamento es obligatorio';
    } else if (v.length < 3) {
      errorDepartamento = 'Mínimo 3 caracteres';
    } else if (v.length > 50) {
      errorDepartamento = 'Máximo 50 caracteres';
    } else {
      errorDepartamento = null;
    }
  }

  bool _validateAll() {
    _validateNombres(_nombresCtrl.text);
    _validateApellidos(_apellidosCtrl.text);
    _validateTelefono(_telefonoCtrl.text);
    _validateDireccion(_direccionCtrl.text);
    _validateCiudad(_ciudadCtrl.text);
    _validateDepartamento(_departamentoCtrl.text);
    return errorNombres == null &&
        errorApellidos == null &&
        errorTelefono == null &&
        errorDireccion == null &&
        errorCiudad == null &&
        errorDepartamento == null;
  }

  Future<void> _saveProfile() async {
    if (!_validateAll()) return;

    setState(() => _isSaving = true);

    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProv.actualizarPerfil(
      token: authProv.token!,
      nombres: _nombresCtrl.text.trim(),
      apellidos: _apellidosCtrl.text.trim(),
      telefono: _telefonoCtrl.text.trim(),
      direccion: _direccionCtrl.text.trim(),
      ciudad: _ciudadCtrl.text.trim(),
      departamento: _departamentoCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil actualizado correctamente'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar el perfil'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _cancelEdit() {
    final profile = Provider.of<AuthProvider>(context, listen: false).userProfile;
    setState(() {
      _isEditing = false;
      _nombresCtrl.text = profile?['nombres'] ?? '';
      _apellidosCtrl.text = profile?['apellidos'] ?? '';
      _telefonoCtrl.text = profile?['telefono'] ?? '';
      _direccionCtrl.text = profile?['direccion'] ?? '';
      _ciudadCtrl.text = profile?['ciudad'] ?? '';
      _departamentoCtrl.text = profile?['departamento'] ?? '';
      errorNombres = null;
      errorApellidos = null;
      errorTelefono = null;
      errorDireccion = null;
      errorCiudad = null;
      errorDepartamento = null;
    });
  }

  static final _allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

  Future<void> _pickAndUploadPhoto() async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Seleccionar foto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppTheme.deepRose),
                title: const Text('Galería'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppTheme.deepRose),
                title: const Text('Cámara'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (picked == null || !mounted) return;

    // Validar extensión
    final ext = picked.name.split('.').last.toLowerCase();
    if (!_allowedExtensions.contains(ext)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo se permiten archivos JPG, PNG y WEBP'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isUploadingPhoto = true);

    final publicUrl = await authProv.subirFotoPerfil(
      token: authProv.token!,
      filePath: picked.path,
    );

    if (!mounted) return;
    setState(() => _isUploadingPhoto = false);

    if (publicUrl != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto de perfil actualizada'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo subir la foto'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProv = Provider.of<AuthProvider>(context);
    final profile = authProv.userProfile;
    final isAdmin = authProv.userRole == 'admin';

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi Perfil')),
        body: const Center(child: Text('No hay datos de perfil disponibles')),
      );
    }

    final nombres = profile['nombres'] ?? '';
    final apellidos = profile['apellidos'] ?? '';
    final fullName = '$nombres $apellidos'.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        actions: [
          if (_isEditing) ...[
            TextButton(
              onPressed: _isSaving ? null : _cancelEdit,
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.deepRose),
                    )
                  : const Text('Guardar', style: TextStyle(color: AppTheme.deepRose, fontWeight: FontWeight.bold)),
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppTheme.deepRose.withValues(alpha: 0.15),
                  backgroundImage: (profile['foto_perfil'] != null && (profile['foto_perfil'] as String).isNotEmpty)
                      ? NetworkImage(profile['foto_perfil'])
                      : null,
                  child: (profile['foto_perfil'] == null || (profile['foto_perfil'] as String).isEmpty)
                      ? Text(
                          fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppTheme.deepRose),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppTheme.deepRose,
                        shape: BoxShape.circle,
                      ),
                      child: _isUploadingPhoto
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(fullName.isNotEmpty ? fullName : 'Sin nombre', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isAdmin ? AppTheme.deepRose.withValues(alpha: 0.1) : AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isAdmin ? 'Administrador' : 'Cliente',
                style: TextStyle(
                  color: isAdmin ? AppTheme.deepRose : AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Información personal
            _buildSection(
              title: 'Información Personal',
              icon: Icons.person_outline,
              children: [
                _isEditing
                    ? _buildEditableField('Nombres', _nombresCtrl, errorNombres, _validateNombres, maxLength: 30)
                    : _buildInfoRow('Nombres', profile['nombres'] ?? ''),
                _isEditing
                    ? _buildEditableField('Apellidos', _apellidosCtrl, errorApellidos, _validateApellidos, maxLength: 30)
                    : _buildInfoRow('Apellidos', profile['apellidos'] ?? ''),
                _buildInfoRow('Correo', profile['email'] ?? ''),
                _isEditing
                    ? _buildEditableField('Teléfono', _telefonoCtrl, errorTelefono, _validateTelefono, maxLength: 15, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly])
                    : _buildInfoRow('Teléfono', profile['telefono'] ?? ''),
              ],
            ),
            const SizedBox(height: 16),

            // Documento (solo lectura)
            _buildSection(
              title: 'Documento',
              icon: Icons.badge_outlined,
              children: [
                _buildInfoRow('Tipo', profile['tipo_documento'] ?? 'CC'),
                _buildInfoRow('Número', profile['documento'] ?? ''),
              ],
            ),
            const SizedBox(height: 16),

            // Dirección
            _buildSection(
              title: 'Dirección',
              icon: Icons.location_on_outlined,
              children: [
                _isEditing
                    ? _buildEditableField('Dirección', _direccionCtrl, errorDireccion, _validateDireccion, maxLength: 40)
                    : _buildInfoRow('Dirección', profile['direccion'] ?? ''),
                _isEditing
                    ? _buildEditableField('Ciudad', _ciudadCtrl, errorCiudad, _validateCiudad, maxLength: 50)
                    : _buildInfoRow('Ciudad', profile['ciudad'] ?? ''),
                _isEditing
                    ? _buildEditableField('Departamento', _departamentoCtrl, errorDepartamento, _validateDepartamento, maxLength: 50)
                    : _buildInfoRow('Departamento', profile['departamento'] ?? ''),
              ],
            ),
            const SizedBox(height: 16),

            // Cambiar contraseña
            _buildSection(
              title: 'Seguridad',
              icon: Icons.lock_outline,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.deepRose.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.lock_reset, color: AppTheme.deepRose, size: 22),
                  ),
                  title: const Text('Cambiar contraseña', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    'Se enviará un código de verificación a tu correo',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.deepRose),
                  onTap: () => _showChangePasswordDialog(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppTheme.deepRose),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.deepRose),
                ),
              ],
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'No especificado',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: value.isNotEmpty ? Colors.black87 : Colors.grey.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller,
    String? error,
    Function(String) onChanged, {
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: (val) => setState(() => onChanged(val)),
        decoration: InputDecoration(
          labelText: '$label *',
          counterText: '',
          border: const OutlineInputBorder(),
          errorText: error,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    _showCodeDialog();
  }

  void _showCodeDialog() {
    final codeCtrl = TextEditingController();
    bool sending = false;
    bool codeSent = false;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.lock_reset, color: AppTheme.deepRose, size: 24),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Verificar identidad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!codeSent) ...[
                  Text(
                    'Se enviará un código de verificación de 6 dígitos a tu correo electrónico para confirmar tu identidad.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  if (sending) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator(color: AppTheme.deepRose)),
                  ],
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Código enviado. Revisa tu correo.',
                            style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    autofocus: true,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
                    decoration: InputDecoration(
                      labelText: 'Código de verificación',
                      counterText: '',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!codeSent && !sending)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    setDialogState(() { sending = true; error = null; });
                    final authProv = Provider.of<AuthProvider>(context, listen: false);
                    final success = await authProv.requestPasswordCode();
                    if (success) {
                      setDialogState(() { codeSent = true; sending = false; });
                    } else {
                      setDialogState(() { sending = false; error = 'Error al enviar el código. Intenta de nuevo.'; });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.deepRose,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('ENVIAR CÓDIGO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            if (codeSent)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final code = codeCtrl.text.trim();
                    if (code.length != 6) {
                      setDialogState(() => error = 'El código debe tener 6 dígitos');
                      return;
                    }
                    Navigator.pop(ctx);
                    _showNewPasswordDialog(code);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.deepRose,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('VERIFICAR CÓDIGO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showNewPasswordDialog(String verificationCode) {
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool changing = false;
    String? error;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.password, color: AppTheme.deepRose, size: 24),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Nueva contraseña', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified, color: Colors.blue, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Identidad verificada. Ahora crea tu nueva contraseña.',
                          style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPassCtrl,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'Nueva contraseña',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mínimo 8 caracteres, 1 mayúscula, 1 minúscula, 1 número y 1 símbolo',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPassCtrl,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirmar contraseña',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: changing ? null : () async {
                  final newPass = newPassCtrl.text.trim();
                  final confirmPass = confirmPassCtrl.text.trim();

                  if (newPass.length < 8) {
                    setDialogState(() => error = 'La contraseña debe tener al menos 8 caracteres');
                    return;
                  }
                  if (newPass != confirmPass) {
                    setDialogState(() => error = 'Las contraseñas no coinciden');
                    return;
                  }

                  setDialogState(() { changing = true; error = null; });
                  final authProv = Provider.of<AuthProvider>(context, listen: false);
                  final result = await authProv.changePassword(
                    newPassword: newPass,
                    verificationCode: verificationCode,
                  );
                  if (result == null) {
                    Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Contraseña actualizada correctamente'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } else {
                    setDialogState(() { changing = false; error = result; });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.deepRose,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: changing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('CAMBIAR CONTRASEÑA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
