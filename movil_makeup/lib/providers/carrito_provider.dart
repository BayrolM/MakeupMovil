import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CartItem {
  final String id;
  final String nombre;
  final double precio;
  final String? imagenUrl;
  int cantidad;
  final int maxStock;

  CartItem({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.cantidad,
    this.imagenUrl,
    this.maxStock = 99,
  });

  Map<String, dynamic> toJson() {
    return {
      'id_producto': int.parse(id),
      'cantidad': cantidad,
    };
  }

  Map<String, dynamic> toStorageJson() {
    return {
      'id': id,
      'nombre': nombre,
      'precio': precio,
      'cantidad': cantidad,
      'imagenUrl': imagenUrl,
      'maxStock': maxStock,
    };
  }

  factory CartItem.fromStorageJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'],
      nombre: json['nombre'],
      precio: (json['precio'] as num).toDouble(),
      cantidad: json['cantidad'],
      imagenUrl: json['imagenUrl'],
      maxStock: json['maxStock'] ?? 99,
    );
  }
}

class CarritoProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};
  final _storage = const FlutterSecureStorage();
  static const _storageKey = 'carrito_items';

  CarritoProvider() {
    _cargarCarrito();
  }

  Map<String, CartItem> get items => {..._items};

  int get itemCount => _items.length;

  int get totalQuantity {
    var quantity = 0;
    _items.forEach((key, item) {
      quantity += item.cantidad;
    });
    return quantity;
  }

  double get totalAmount {
    var total = 0.0;
    _items.forEach((key, item) {
      total += item.precio * item.cantidad;
    });
    return total;
  }

  Future<void> _cargarCarrito() async {
    try {
      final data = await _storage.read(key: _storageKey);
      if (data != null && data.isNotEmpty) {
        final List<dynamic> decoded = json.decode(data);
        for (final item in decoded) {
          final cartItem = CartItem.fromStorageJson(item);
          _items[cartItem.id] = cartItem;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error cargando carrito: $e');
    }
  }

  Future<void> _guardarCarrito() async {
    try {
      final data = _items.values.map((item) => item.toStorageJson()).toList();
      await _storage.write(key: _storageKey, value: json.encode(data));
    } catch (e) {
      debugPrint('Error guardando carrito: $e');
    }
  }

  /// Retorna true si se agregó, false si alcanzó stock máximo
  bool agregarProducto({
    required String id,
    required String nombre,
    required double precio,
    required int maxStock,
    String? imagenUrl,
  }) {
    if (_items.containsKey(id)) {
      if (_items[id]!.cantidad >= maxStock) return false;
      _items.update(
        id,
        (existingItem) => CartItem(
          id: existingItem.id,
          nombre: existingItem.nombre,
          precio: existingItem.precio,
          cantidad: existingItem.cantidad + 1,
          imagenUrl: existingItem.imagenUrl,
          maxStock: maxStock,
        ),
      );
      notifyListeners();
      _guardarCarrito();
      return true;
    } else {
      if (maxStock <= 0) return false;
      _items.putIfAbsent(
        id,
        () => CartItem(
          id: id,
          nombre: nombre,
          precio: precio,
          cantidad: 1,
          imagenUrl: imagenUrl,
          maxStock: maxStock,
        ),
      );
      notifyListeners();
      _guardarCarrito();
      return true;
    }
  }

  /// Retorna true si se incrementó, false si ya está en stock máximo
  bool agregarUno(String id) {
    if (!_items.containsKey(id)) return false;
    final item = _items[id]!;
    if (item.cantidad >= item.maxStock) return false;
    _items.update(
      id,
      (existingItem) => CartItem(
        id: existingItem.id,
        nombre: existingItem.nombre,
        precio: existingItem.precio,
        cantidad: existingItem.cantidad + 1,
        imagenUrl: existingItem.imagenUrl,
        maxStock: existingItem.maxStock,
      ),
    );
    notifyListeners();
    _guardarCarrito();
    return true;
  }

  /// Retorna true si se设置 correctamente, false si la cantidad excede el stock
  bool setCantidad(String id, int cantidad) {
    if (!_items.containsKey(id)) return false;
    final item = _items[id]!;
    if (cantidad > item.maxStock) return false;
    if (cantidad <= 0) {
      _items.remove(id);
    } else {
      _items.update(
        id,
        (existingItem) => CartItem(
          id: existingItem.id,
          nombre: existingItem.nombre,
          precio: existingItem.precio,
          cantidad: cantidad,
          imagenUrl: existingItem.imagenUrl,
          maxStock: existingItem.maxStock,
        ),
      );
    }
    notifyListeners();
    _guardarCarrito();
    return true;
  }

  /// Ajusta la cantidad al máximo de stock disponible
  void ajustarAMaxStock(String id) {
    if (!_items.containsKey(id)) return;
    final item = _items[id]!;
    if (item.cantidad > item.maxStock) {
      _items.update(
        id,
        (existingItem) => CartItem(
          id: existingItem.id,
          nombre: existingItem.nombre,
          precio: existingItem.precio,
          cantidad: existingItem.maxStock,
          imagenUrl: existingItem.imagenUrl,
          maxStock: existingItem.maxStock,
        ),
      );
      notifyListeners();
      _guardarCarrito();
    }
  }

  int getMaxStock(String id) {
    return _items[id]?.maxStock ?? 99;
  }

  void removerUno(String id) {
    if (!_items.containsKey(id)) return;
    if (_items[id]!.cantidad > 1) {
      _items.update(
        id,
        (existingItem) => CartItem(
          id: existingItem.id,
          nombre: existingItem.nombre,
          precio: existingItem.precio,
          cantidad: existingItem.cantidad - 1,
          imagenUrl: existingItem.imagenUrl,
          maxStock: existingItem.maxStock,
        ),
      );
    } else {
      _items.remove(id);
    }
    notifyListeners();
    _guardarCarrito();
  }

  void eliminarItem(String id) {
    _items.remove(id);
    notifyListeners();
    _guardarCarrito();
  }

  void limpiar() {
    _items.clear();
    notifyListeners();
    _guardarCarrito();
  }

  List<Map<String, dynamic>> get apiItems {
    return _items.values.map((item) => item.toJson()).toList();
  }
}
