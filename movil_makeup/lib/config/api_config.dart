import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  /// Retorna la URL base de la API REST (ej. http://10.0.2.2:3000/api)
  static String get baseUrl {
    final envUrl = dotenv.env['API_URL'];
    if (envUrl != null && envUrl.isNotEmpty) return envUrl;
    return 'http://10.0.2.2:3000/api'; 
  }

  /// Retorna el dominio base del servidor sin el sufijo /api (ej. http://10.0.2.2:3000)
  /// Útil para resolver rutas estáticas de imágenes u otros uploads.
  static String get baseDomain {
    final url = baseUrl;
    String domain = url.replaceAll('/api', '');
    if (domain.endsWith('/')) {
      domain = domain.substring(0, domain.length - 1);
    }
    return domain;
  }
}
