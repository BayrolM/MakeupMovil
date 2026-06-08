import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ProductModel {
  final String id;
  final String nombre;
  final String descripcion;
  final double precioVenta;
  final int stock;
  final String? imagenUrl;
  final String categoriaId;
  final String marca;

  ProductModel({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.precioVenta,
    required this.stock,
    required this.categoriaId,
    required this.marca,
    this.imagenUrl,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id_producto'].toString(),
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'] ?? '',
      precioVenta: double.tryParse(json['precio_venta'].toString()) ?? 0.0,
      stock: json['stock_actual'] ?? 0,
      categoriaId: json['id_categoria'].toString(),
      marca: json['nombre_marca'] ?? 'Genérica',
      imagenUrl: json['imagen_url'],
    );
  }
}

class CategoryModel {
  final String id;
  final String nombre;
  final String descripcion;

  CategoryModel({
    required this.id,
    required this.nombre,
    required this.descripcion,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id_categoria'].toString(),
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'] ?? '',
    );
  }
}

class ProductoProvider with ChangeNotifier {
  List<ProductModel> _productos = [];
  List<CategoryModel> _categorias = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ProductModel> get productos => [..._productos];
  List<ProductModel> get productosDisponibles => _productos.where((p) => p.stock > 0).toList();
  List<CategoryModel> get categorias => [..._categorias];
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get _baseUrl => ApiConfig.baseUrl;

  /// Cargar productos públicos de la API
  Future<void> cargarProductos({String? search, String? categoryId, bool? estado = true}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      var urlStr = '$_baseUrl/products?limit=100';
      if (search != null && search.isNotEmpty) {
        urlStr += '&q=${Uri.encodeComponent(search)}';
      }
      if (categoryId != null && categoryId.isNotEmpty) {
        urlStr += '&categoria=$categoryId';
      }
      if (estado != null) {
        urlStr += '&estado=$estado';
      }

      final response = await http.get(Uri.parse(urlStr));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> prodList = data['data'] ?? [];
        _productos = prodList.map((json) => ProductModel.fromJson(json)).toList();
      } else {
        _errorMessage = "No se pudieron cargar los productos";
      }
    } catch (e) {
      _errorMessage = "Error de conexión al obtener catálogo.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cargar categorías públicas de la API
  Future<void> cargarCategorias() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/categorias?limit=100'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> catList = data['data'] ?? [];
        _categorias = catList.map((json) => CategoryModel.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (e) {
      // Manejar error silenciosamente o reportar
    }
  }
}
