import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

/// Retorna una URL segura para cargar imágenes en cualquier plataforma (Web, Android, iOS).
/// Resuelve problemas de políticas CORS en Web redirigiendo URLs externas a través de weserv.nl,
/// manteniendo intactas las URLs locales (para pruebas) y las de Supabase Storage.
String getSafeImageUrl(String? url) {
  if (url == null || url.trim().isEmpty) {
    return '';
  }

  // Si la URL empieza con http:// o https://
  if (url.startsWith('http://') || url.startsWith('https://')) {
    // Si es una URL local de desarrollo, no aplicar proxy
    if (url.contains('localhost') ||
        url.contains('10.0.2.2') ||
        url.contains('127.0.0.1') ||
        url.contains('192.168.')) {
      return url;
    }

    // Si ya viene de Supabase Storage, usualmente viene de buckets con CORS público configurado
    if (url.contains('supabase.co')) {
      return url;
    }

    // Si estamos en la plataforma Web y es una URL externa, aplicamos el proxy para evitar bloqueos CORS
    if (kIsWeb) {
      return 'https://images.weserv.nl/?url=${Uri.encodeComponent(url)}';
    }
    
    return url;
  }

  // Si es una URL relativa del backend (ej. /uploads/comprobantes/...)
  final base = ApiConfig.baseDomain;
  final normalizedPath = url.startsWith('/') ? url : '/$url';
  return '$base$normalizedPath';
}
