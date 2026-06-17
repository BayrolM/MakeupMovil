import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/api_config.dart';

class AuthProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  
  String? _token;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = false;
  String? _errorMessage;

  String? get token => _token;
  bool get isLoggedIn => _token != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get userProfile => _userProfile;

  String get userRole {
    if (_userProfile != null && _userProfile!['id_rol'] != null) {
      final roleId = _userProfile!['id_rol'];
      return roleId == 1 ? 'admin' : 'cliente';
    }
    return 'cliente';
  }

  String get _baseUrl => ApiConfig.baseUrl;

  AuthProvider() {
    _tryAutoLogin();
  }

  /// Intento de inicio de sesión automático usando el token guardado
  Future<void> _tryAutoLogin() async {
    _isLoading = true;
    notifyListeners();
    try {
      final savedToken = await _storage.read(key: 'auth_token');
      if (savedToken != null) {
        _token = savedToken;
        final profileSuccess = await _fetchProfile(savedToken);
        if (!profileSuccess) {
          await logout();
        }
      }
    } catch (e) {
      _errorMessage = "Error cargando la sesión previa.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Iniciar sesión en la API Express
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['token'] != null) {
        final token = data['token'];
        _token = token;
        await _storage.write(key: 'auth_token', value: token);

        // Obtener el perfil del usuario para saber el Rol
        final profileSuccess = await _fetchProfile(token);
        _isLoading = false;
        notifyListeners();
        return profileSuccess;
      } else {
        _errorMessage = data['message'] ?? 'Credenciales incorrectas';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'No se pudo conectar al servidor. Verifica la URL de API.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Registrar nuevo usuario cliente
  Future<bool> register({
    required String nombres,
    required String apellidos,
    required String email,
    required String telefono,
    required String password,
    String? documento,
    String? direccion,
    String? ciudad,
    String? departamento,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'nombres': nombres,
          'apellidos': apellidos,
          'email': email,
          'telefono': telefono,
          'password': password,
          'tipo_documento': 'CC',
          'documento': documento ?? '',
          'direccion': direccion ?? '',
          'ciudad': ciudad ?? '',
          'departamento': departamento ?? '',
          'id_rol': 2 // Rol cliente por defecto
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['message'] ?? 'Error al registrar el usuario';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'No se pudo conectar al servidor.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Obtener el perfil del usuario
  Future<bool> _fetchProfile(String authToken) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      if (response.statusCode == 200) {
        _userProfile = json.decode(response.body);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Actualizar perfil del usuario
  Future<bool> actualizarPerfil({
    required String token,
    String? nombres,
    String? apellidos,
    String? telefono,
    String? direccion,
    String? ciudad,
    String? departamento,
    String? fotoPerfil,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (nombres != null) body['nombres'] = nombres;
      if (apellidos != null) body['apellidos'] = apellidos;
      if (telefono != null) body['telefono'] = telefono;
      if (direccion != null) body['direccion'] = direccion;
      if (ciudad != null) body['ciudad'] = ciudad;
      if (departamento != null) body['departamento'] = departamento;
      if (fotoPerfil != null) body['foto_perfil'] = fotoPerfil;

      final response = await http.put(
        Uri.parse('$_baseUrl/users/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        if (_userProfile != null) {
          if (nombres != null) _userProfile!['nombres'] = nombres;
          if (apellidos != null) _userProfile!['apellidos'] = apellidos;
          if (telefono != null) _userProfile!['telefono'] = telefono;
          if (direccion != null) _userProfile!['direccion'] = direccion;
          if (ciudad != null) _userProfile!['ciudad'] = ciudad;
          if (departamento != null) _userProfile!['departamento'] = departamento;
          if (fotoPerfil != null) _userProfile!['foto_perfil'] = fotoPerfil;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Subir foto de perfil a Supabase Storage y actualizar perfil
  Future<String?> subirFotoPerfil({
    required String token,
    required String filePath,
  }) async {
    try {
      print('📸 [Foto] Archivo original: $filePath');

      final supabase = Supabase.instance.client;
      final userId = _userProfile?['id_usuario'] ?? 'unknown';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      if (kIsWeb) {
        // En web: leer bytes desde el blob URL
        print('📸 [Foto] Plataforma: WEB');
        final response = await http.get(Uri.parse(filePath));
        if (response.statusCode != 200) {
          print('📸 [Foto] ERROR: No se pudo leer el archivo: ${response.statusCode}');
          return null;
        }
        final bytes = response.bodyBytes;
        print('📸 [Foto] Bytes leídos: ${bytes.length}');

        final storagePath = 'avatars/user_${userId}_${timestamp}.jpg';
        print('📸 [Foto] Subiendo a Storage: $storagePath');

        await supabase.storage.from('avatars').uploadBinary(
              storagePath,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
        print('📸 [Foto] Subida exitosa');

        final publicUrl = supabase.storage.from('avatars').getPublicUrl(storagePath);
        print('📸 [Foto] URL pública: $publicUrl');

        final success = await actualizarPerfil(token: token, fotoPerfil: publicUrl);
        print('📸 [Foto] Backend actualizado: $success');
        if (success) return publicUrl;
      } else {
        // En móvil
        print('📸 [Foto] Plataforma: MÓVIL');
        final file = File(filePath);
        final ext = filePath.split('.').last.toLowerCase();

        final allowedExts = ['jpg', 'jpeg', 'png', 'webp'];
        if (!allowedExts.contains(ext)) {
          print('📸 [Foto] ERROR: Formato no permitido: $ext');
          return null;
        }

        final contentType = ext == 'png'
            ? 'image/png'
            : ext == 'webp'
                ? 'image/webp'
                : 'image/jpeg';
        final storagePath = 'avatars/user_${userId}_${timestamp}.$ext';
        print('📸 [Foto] Subiendo a Storage: $storagePath');

        await supabase.storage.from('avatars').upload(
              storagePath,
              file,
              fileOptions: FileOptions(contentType: contentType, upsert: true),
            );
        print('📸 [Foto] Subida exitosa');

        final publicUrl = supabase.storage.from('avatars').getPublicUrl(storagePath);
        print('📸 [Foto] URL pública: $publicUrl');

        final success = await actualizarPerfil(token: token, fotoPerfil: publicUrl);
        print('📸 [Foto] Backend actualizado: $success');
        if (success) return publicUrl;
      }

      return null;
    } catch (e, stackTrace) {
      print('📸 [Foto] ERROR: $e');
      print('📸 [Foto] STACK: $stackTrace');
      return null;
    }
  }

  /// Cerrar Sesión y borrar tokens
  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    _token = null;
    _userProfile = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Verificar correo con código de 6 dígitos
  Future<bool> verifyEmail({required String email, required String code}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/verify-email'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'code': code}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['token'] != null) {
        final token = data['token'];
        _token = token;
        await _storage.write(key: 'auth_token', value: token);
        await _fetchProfile(token);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['message'] ?? 'Código incorrecto';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'No se pudo conectar al servidor.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Verificar si un email ya está registrado
  Future<bool> checkEmail(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/check-email'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['registered'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Solicitar código de cambio de contraseña (envía email)
  Future<bool> requestPasswordCode() async {
    if (_token == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/users/profile/password/code'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Cambiar contraseña con código de verificación
  Future<String?> changePassword({required String newPassword, required String verificationCode}) async {
    if (_token == null) return 'No autenticado';
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/profile/password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode({
          'newPassword': newPassword,
          'verificationCode': verificationCode,
        }),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200) return null;
      return data['message'] ?? 'Error al cambiar contraseña';
    } catch (e) {
      return 'Error de conexión';
    }
  }
}
