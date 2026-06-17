import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class OrderItemModel {
  final String idProducto;
  final String nombreProducto;
  final int cantidad;
  final double precioUnitario;
  final double subtotal;

  OrderItemModel({
    required this.idProducto,
    required this.nombreProducto,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      idProducto: json['id_producto'].toString(),
      nombreProducto: json['nombre_producto'] ?? json['nombre'] ?? 'Producto',
      cantidad: json['cantidad'] ?? 0,
      precioUnitario: double.tryParse(json['precio_unitario']?.toString() ?? '') ?? 0.0,
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '') ?? 0.0,
    );
  }
}

class OrderModel {
  final String id;
  final String fecha;
  final String direccion;
  final String ciudad;
  final String? departamento;
  final double total;
  final String estado;
  final String metodoPago;
  final bool pagoConfirmado;
  final String? comprobanteUrl;
  final String? clienteNombre;
  final String? clienteEmail;
  final String? transportadora;
  final String? numeroGuia;
  final String? trackingLink;
  final String? fechaEnvio;
  final String? fechaEstimada;
  final double? valorPedido;
  final String? estadoDevolucion;
  final Map<String, dynamic>? devolucionInfo;
  final String? motivoAnulacion;
  final List<OrderItemModel> items;

  OrderModel({
    required this.id,
    required this.fecha,
    required this.direccion,
    required this.ciudad,
    required this.total,
    required this.estado,
    required this.metodoPago,
    required this.pagoConfirmado,
    this.departamento,
    this.comprobanteUrl,
    this.clienteNombre,
    this.clienteEmail,
    this.transportadora,
    this.numeroGuia,
    this.trackingLink,
    this.fechaEnvio,
    this.fechaEstimada,
    this.valorPedido,
    this.estadoDevolucion,
    this.devolucionInfo,
    this.motivoAnulacion,
    required this.items,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'] as List? ?? [];
    List<OrderItemModel> parsedItems = rawItems.map((item) => OrderItemModel.fromJson(item)).toList();

    return OrderModel(
      id: json['id_pedido'].toString(),
      fecha: json['fecha_pedido'] ?? '',
      direccion: json['direccion'] ?? '',
      ciudad: json['ciudad'] ?? '',
      departamento: json['departamento'],
      total: double.tryParse(json['total']?.toString() ?? '') ?? 0.0,
      estado: json['estado'] ?? 'pendiente',
      metodoPago: json['metodo_pago'] ?? 'efectivo',
      pagoConfirmado: json['pago_confirmado'] == true || json['pago_confirmado'] == 1,
      comprobanteUrl: json['comprobante_url'],
      clienteNombre: json['nombre_usuario'] ?? json['nombre_cliente'],
      clienteEmail: json['email_usuario'],
      transportadora: json['transportadora'],
      numeroGuia: json['numero_guia'],
      trackingLink: json['tracking_link'],
      fechaEnvio: json['fecha_envio'],
      fechaEstimada: json['fecha_estimada'],
      valorPedido: double.tryParse(json['valor_pedido']?.toString() ?? '') ?? 0.0,
      estadoDevolucion: json['estado_devolucion'],
      devolucionInfo: json['devolucion_info'] is Map ? json['devolucion_info'] : null,
      motivoAnulacion: json['motivo_anulacion'],
      items: parsedItems,
    );
  }
}

class PedidoProvider with ChangeNotifier {
  List<OrderModel> _pedidos = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<OrderModel> get pedidos => [..._pedidos];
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get _baseUrl => ApiConfig.baseUrl;

  /// Crear pedido desde la aplicación móvil
  /// Crea un pedido y retorna el ID del pedido creado (o null si falla)
  Future<String?> crearPedido({
    required String token,
    required String direccion,
    required String ciudad,
    required String departamento,
    required String metodoPago,
    required List<Map<String, dynamic>> items,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/orders'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'direccion': direccion,
          'ciudad': ciudad,
          'departamento': departamento,
          'metodo_pago': metodoPago,
          'items': items,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201 && data['ok'] == true) {
        final orderId = data['data']['id_pedido'].toString();
        _isLoading = false;
        notifyListeners();
        return orderId;
      } else {
        _errorMessage = data['message'] ?? 'Error al procesar el pedido';
        _isLoading = false;
        notifyListeners();
        return null;
      }
    } catch (e) {
      _errorMessage = 'Error de conexión. Reintente en un momento.';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Cargar historial de pedidos para el cliente actual
  Future<void> cargarPedidosCliente(String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/orders'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> ordersList = data['data'] ?? [];
        final fetched = ordersList.map((json) => OrderModel.fromJson(json)).toList();

        // Preservar items y datos de envío ya cargados de pedidos anteriores
        _pedidos = fetched.map((pedido) {
          final existing = _pedidos.firstWhere(
            (p) => p.id == pedido.id,
            orElse: () => pedido,
          );
          return OrderModel(
            id: pedido.id,
            fecha: pedido.fecha,
            direccion: pedido.direccion,
            ciudad: pedido.ciudad,
            departamento: pedido.departamento,
            total: pedido.total,
            estado: pedido.estado,
            pagoConfirmado: pedido.pagoConfirmado,
            comprobanteUrl: pedido.comprobanteUrl ?? existing.comprobanteUrl,
            clienteNombre: pedido.clienteNombre ?? existing.clienteNombre,
            clienteEmail: pedido.clienteEmail ?? existing.clienteEmail,
            metodoPago: pedido.metodoPago,
            transportadora: pedido.transportadora ?? existing.transportadora,
            numeroGuia: pedido.numeroGuia ?? existing.numeroGuia,
            trackingLink: pedido.trackingLink ?? existing.trackingLink,
            fechaEnvio: pedido.fechaEnvio ?? existing.fechaEnvio,
            fechaEstimada: pedido.fechaEstimada ?? existing.fechaEstimada,
            valorPedido: pedido.valorPedido != null && pedido.valorPedido! > 0 ? pedido.valorPedido : existing.valorPedido,
            estadoDevolucion: pedido.estadoDevolucion ?? existing.estadoDevolucion,
            devolucionInfo: pedido.devolucionInfo ?? existing.devolucionInfo,
            motivoAnulacion: pedido.motivoAnulacion ?? existing.motivoAnulacion,
            items: existing.items.isNotEmpty ? existing.items : pedido.items,
          );
        }).toList();
      } else {
        _errorMessage = 'No se pudieron cargar los pedidos.';
      }
    } catch (e) {
      _errorMessage = 'Error de red al consultar pedidos.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cargar todos los pedidos del sistema para el Admin
  Future<void> cargarTodosLosPedidos(String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/orders'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> ordersList = data['data'] ?? [];
        final fetched = ordersList.map((json) => OrderModel.fromJson(json)).toList();

        // Preservar items y datos de envío ya cargados de pedidos anteriores
        _pedidos = fetched.map((pedido) {
          final existing = _pedidos.firstWhere(
            (p) => p.id == pedido.id,
            orElse: () => pedido,
          );
          return OrderModel(
            id: pedido.id,
            fecha: pedido.fecha,
            direccion: pedido.direccion,
            ciudad: pedido.ciudad,
            departamento: pedido.departamento,
            total: pedido.total,
            estado: pedido.estado,
            pagoConfirmado: pedido.pagoConfirmado,
            comprobanteUrl: pedido.comprobanteUrl ?? existing.comprobanteUrl,
            clienteNombre: pedido.clienteNombre ?? existing.clienteNombre,
            clienteEmail: pedido.clienteEmail ?? existing.clienteEmail,
            metodoPago: pedido.metodoPago,
            transportadora: pedido.transportadora ?? existing.transportadora,
            numeroGuia: pedido.numeroGuia ?? existing.numeroGuia,
            trackingLink: pedido.trackingLink ?? existing.trackingLink,
            fechaEnvio: pedido.fechaEnvio ?? existing.fechaEnvio,
            fechaEstimada: pedido.fechaEstimada ?? existing.fechaEstimada,
            valorPedido: pedido.valorPedido != null && pedido.valorPedido! > 0 ? pedido.valorPedido : existing.valorPedido,
            estadoDevolucion: pedido.estadoDevolucion ?? existing.estadoDevolucion,
            devolucionInfo: pedido.devolucionInfo ?? existing.devolucionInfo,
            motivoAnulacion: pedido.motivoAnulacion ?? existing.motivoAnulacion,
            items: existing.items.isNotEmpty ? existing.items : pedido.items,
          );
        }).toList();
      } else {
        _errorMessage = 'Error al cargar listado administrativo de pedidos.';
      }
    } catch (e) {
      _errorMessage = 'Error al conectar con la API de administración.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Actualizar estado del pedido (Admin)
  Future<bool> actualizarEstado({
    required String token,
    required String idPedido,
    required String nuevoEstado,
    required int idEmpleado,
    String? motivo,
    Map<String, dynamic>? shippingData,
  }) async {
    try {
      final body = <String, dynamic>{
        'estado': nuevoEstado,
        'id_usuario_empleado': idEmpleado,
        'motivo': motivo ?? 'Estado actualizado desde la app móvil',
      };
      if (shippingData != null) {
        body['shippingData'] = shippingData;
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/orders/$idPedido/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        // Recargar pedidos locales
        final index = _pedidos.indexWhere((p) => p.id == idPedido);
        if (index != -1) {
          // Cambiar estado localmente para feedback inmediato
          final old = _pedidos[index];
          _pedidos[index] = OrderModel(
            id: old.id,
            fecha: old.fecha,
            direccion: old.direccion,
            ciudad: old.ciudad,
            departamento: old.departamento,
            total: old.total,
            estado: nuevoEstado,
            metodoPago: old.metodoPago,
            pagoConfirmado: old.pagoConfirmado,
            comprobanteUrl: old.comprobanteUrl,
            clienteNombre: old.clienteNombre,
            clienteEmail: old.clienteEmail,
            transportadora: shippingData?['transportadora'] ?? old.transportadora,
            numeroGuia: shippingData?['numero_guia'] ?? old.numeroGuia,
            trackingLink: shippingData?['tracking_link'] ?? old.trackingLink,
            fechaEnvio: shippingData?['fecha_envio'] ?? old.fechaEnvio,
            fechaEstimada: shippingData?['fecha_estimada'] ?? old.fechaEstimada,
            valorPedido: shippingData?['valor_pedido'] != null
                ? double.tryParse(shippingData!['valor_pedido'].toString()) ?? old.valorPedido
                : old.valorPedido,
            motivoAnulacion: old.motivoAnulacion,
            items: old.items,
          );
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Crear pedido directo por un administrador (para un cliente específico)
  Future<bool> crearPedidoAdmin({
    required String token,
    required int idCliente,
    required String direccion,
    required String ciudad,
    required String departamento,
    required String metodoPago,
    required List<Map<String, dynamic>> items,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/orders/admin'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'id_cliente': idCliente,
          'direccion': direccion,
          'ciudad': ciudad,
          'departamento': departamento,
          'metodo_pago': metodoPago,
          'items': items,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201 && data['ok'] == true) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['message'] ?? 'Error al procesar el pedido administrativo';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error de conexión con la API de administración.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Obtener detalle completo de un pedido (incluyendo items) y actualizarlo localmente
  Future<void> cargarDetallePedido(String token, String idPedido) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/orders/$idPedido'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rawOrder = data['data'];
        if (rawOrder != null) {
          final updatedOrder = OrderModel.fromJson(rawOrder);
          
          // Reemplazar o actualizar en la lista de pedidos local
          final index = _pedidos.indexWhere((p) => p.id == idPedido);
          if (index != -1) {
            final existing = _pedidos[index];
            // Preservar campos que el detalle no trae (backend bug: GET /:id no incluye pago_confirmado y comprobante_url para clientes)
            _pedidos[index] = OrderModel(
              id: updatedOrder.id,
              fecha: updatedOrder.fecha,
              direccion: updatedOrder.direccion,
              ciudad: updatedOrder.ciudad,
              departamento: updatedOrder.departamento,
              total: updatedOrder.total,
              estado: updatedOrder.estado,
              metodoPago: updatedOrder.metodoPago,
              pagoConfirmado: rawOrder['pago_confirmado'] != null
                  ? (rawOrder['pago_confirmado'] == true || rawOrder['pago_confirmado'] == 1)
                  : existing.pagoConfirmado,
              comprobanteUrl: (rawOrder['comprobante_url'] != null && rawOrder['comprobante_url'].toString().isNotEmpty)
                  ? rawOrder['comprobante_url']
                  : existing.comprobanteUrl,
              clienteNombre: updatedOrder.clienteNombre ?? existing.clienteNombre,
              clienteEmail: updatedOrder.clienteEmail ?? existing.clienteEmail,
              transportadora: updatedOrder.transportadora ?? existing.transportadora,
              numeroGuia: updatedOrder.numeroGuia ?? existing.numeroGuia,
              trackingLink: updatedOrder.trackingLink ?? existing.trackingLink,
              fechaEnvio: updatedOrder.fechaEnvio ?? existing.fechaEnvio,
              fechaEstimada: updatedOrder.fechaEstimada ?? existing.fechaEstimada,
              valorPedido: updatedOrder.valorPedido != null && updatedOrder.valorPedido! > 0 ? updatedOrder.valorPedido : existing.valorPedido,
              estadoDevolucion: updatedOrder.estadoDevolucion ?? existing.estadoDevolucion,
              devolucionInfo: updatedOrder.devolucionInfo ?? existing.devolucionInfo,
              motivoAnulacion: updatedOrder.motivoAnulacion ?? existing.motivoAnulacion,
              items: updatedOrder.items.isNotEmpty ? updatedOrder.items : existing.items,
            );
            notifyListeners();
          }
        }
      }
    } catch (e) {
      // Manejar error silenciosamente
      debugPrint("Error cargando detalle de pedido: $e");
    }
  }

  /// Actualizar URL del comprobante de pago
  Future<bool> actualizarComprobanteUrl({
    required String token,
    required String idPedido,
    required String comprobanteUrl,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/orders/$idPedido/comprobante_url'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'url': comprobanteUrl}),
      );

      if (response.statusCode == 200) {
        final index = _pedidos.indexWhere((p) => p.id == idPedido);
        if (index != -1) {
          final old = _pedidos[index];
          _pedidos[index] = OrderModel(
            id: old.id,
            fecha: old.fecha,
            direccion: old.direccion,
            ciudad: old.ciudad,
            departamento: old.departamento,
            total: old.total,
            estado: old.estado,
            metodoPago: old.metodoPago,
            pagoConfirmado: old.pagoConfirmado,
            comprobanteUrl: comprobanteUrl,
            clienteNombre: old.clienteNombre,
            clienteEmail: old.clienteEmail,
            transportadora: old.transportadora,
            numeroGuia: old.numeroGuia,
            trackingLink: old.trackingLink,
            fechaEnvio: old.fechaEnvio,
            fechaEstimada: old.fechaEstimada,
            motivoAnulacion: old.motivoAnulacion,
            items: old.items,
          );
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Confirmar o rechazar pago (Admin) — solo cambia el flag pago_confirmado
  Future<bool> confirmarPago({
    required String token,
    required String idPedido,
    required bool confirmado,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/orders/$idPedido/pago'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'pago_confirmado': confirmado,
        }),
      );

      if (response.statusCode == 200) {
        final index = _pedidos.indexWhere((p) => p.id == idPedido);
        if (index != -1) {
          final old = _pedidos[index];
          _pedidos[index] = OrderModel(
            id: old.id,
            fecha: old.fecha,
            direccion: old.direccion,
            ciudad: old.ciudad,
            departamento: old.departamento,
            total: old.total,
            estado: old.estado,
            metodoPago: old.metodoPago,
            pagoConfirmado: confirmado,
            comprobanteUrl: old.comprobanteUrl,
            clienteNombre: old.clienteNombre,
            clienteEmail: old.clienteEmail,
            transportadora: old.transportadora,
            numeroGuia: old.numeroGuia,
            trackingLink: old.trackingLink,
            fechaEnvio: old.fechaEnvio,
            fechaEstimada: old.fechaEstimada,
            motivoAnulacion: old.motivoAnulacion,
            items: old.items,
          );
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Cancelar pedido desde el cliente
  Future<bool> cancelarPedidoCliente({
    required String token,
    required String idPedido,
    String? motivo,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/orders/$idPedido/cancel-client'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'motivo': motivo?.isNotEmpty == true ? motivo : 'Cancelado por el cliente',
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['ok'] == true) {
        final index = _pedidos.indexWhere((p) => p.id == idPedido);
        if (index != -1) {
          final old = _pedidos[index];
          _pedidos[index] = OrderModel(
            id: old.id,
            fecha: old.fecha,
            direccion: old.direccion,
            ciudad: old.ciudad,
            departamento: old.departamento,
            total: old.total,
            estado: 'cancelado',
            metodoPago: old.metodoPago,
            pagoConfirmado: old.pagoConfirmado,
            comprobanteUrl: old.comprobanteUrl,
            clienteNombre: old.clienteNombre,
            clienteEmail: old.clienteEmail,
            transportadora: old.transportadora,
            numeroGuia: old.numeroGuia,
            trackingLink: old.trackingLink,
            fechaEnvio: old.fechaEnvio,
            fechaEstimada: old.fechaEstimada,
            motivoAnulacion: motivo,
            items: old.items,
          );
          notifyListeners();
        }
        return true;
      }
      _errorMessage = data['message'] ?? 'Error al cancelar el pedido';
      return false;
    } catch (e) {
      _errorMessage = 'Error de conexión al cancelar el pedido';
      return false;
    }
  }
}
