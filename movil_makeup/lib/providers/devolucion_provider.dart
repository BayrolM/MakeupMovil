import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/api_config.dart';

class DevolucionProvider with ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get _baseUrl => ApiConfig.baseUrl;

  /// Subir imagen de evidencia a Supabase Storage bucket 'comprobantes'
  Future<String?> subirEvidencia({required Uint8List bytes, required String fileName, required String userId}) async {
    try {
      final supabase = Supabase.instance.client;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ext = fileName.split('.').last.toLowerCase();
      final storagePath = 'devoluciones/evidencia_${userId}_$timestamp.$ext';

      final contentType = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
              ? 'image/webp'
              : 'image/jpeg';

      await supabase.storage.from('comprobantes').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );

      final publicUrl = supabase.storage.from('comprobantes').getPublicUrl(storagePath);
      return publicUrl;
    } catch (e) {
      _errorMessage = 'Error al subir evidencia: $e';
      notifyListeners();
      return null;
    }
  }

  /// Crear una devolución
  Future<bool> crearDevolucion({
    required String token,
    required String idPedido,
    required String idUsuarioCliente,
    required String motivo,
    required bool esDefectuoso,
    required List<Map<String, dynamic>> productos,
    String? evidenciaUrl,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = {
        'id_pedido': int.parse(idPedido),
        'id_usuario_cliente': int.parse(idUsuarioCliente),
        'motivo': motivo.trim(),
        'estado': 'pendiente',
        'es_defectuoso': esDefectuoso,
        'productos': productos,
      };

      if (evidenciaUrl != null) {
        body['evidencia_url'] = evidenciaUrl;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/devoluciones'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['message'] ?? 'Error al crear la devolución';
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
}
