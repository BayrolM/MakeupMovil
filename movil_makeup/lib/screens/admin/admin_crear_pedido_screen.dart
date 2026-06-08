import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../providers/auth_provider.dart';
import '../../providers/producto_provider.dart';
import '../../providers/pedido_provider.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';

class ClientOption {
  final int idUsuario;
  final String nombres;
  final String apellidos;
  final String email;
  final String? direccion;
  final String? ciudad;
  final String? departamento;

  ClientOption({
    required this.idUsuario,
    required this.nombres,
    required this.apellidos,
    required this.email,
    this.direccion,
    this.ciudad,
    this.departamento,
  });

  factory ClientOption.fromJson(Map<String, dynamic> json) {
    return ClientOption(
      idUsuario: json['id_usuario'],
      nombres: json['nombres'] ?? json['nombre'] ?? '',
      apellidos: json['apellidos'] ?? json['apellido'] ?? '',
      email: json['email'] ?? '',
      direccion: json['direccion'],
      ciudad: json['ciudad'],
      departamento: json['departamento'],
    );
  }

  String get fullName => '$nombres $apellidos';
}

class AdminCrearPedidoScreen extends StatefulWidget {
  const AdminCrearPedidoScreen({super.key});

  @override
  State<AdminCrearPedidoScreen> createState() => _AdminCrearPedidoScreenState();
}

class _AdminCrearPedidoScreenState extends State<AdminCrearPedidoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _direccionController = TextEditingController();
  final _ciudadController = TextEditingController();
  final _departamentoController = TextEditingController();
  final _cantidadController = TextEditingController(text: '1');

  List<ClientOption> _clientes = [];
  ClientOption? _selectedCliente;
  bool _loadingClientes = false;

  ProductModel? _selectedProduct;
  String _metodoPago = 'efectivo';

  // Ítems añadidos al pedido
  final List<Map<String, dynamic>> _addedItems = [];
  double _grandTotal = 0.0;

  final currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    // Cargar productos si no están cargados
    final productProv = Provider.of<ProductoProvider>(context, listen: false);
    if (productProv.productos.isEmpty) {
      productProv.cargarProductos();
    }
    _fetchClientes();
  }

  Future<void> _fetchClientes() async {
    setState(() {
      _loadingClientes = true;
    });

    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final token = authProv.token;

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users?limit=200&estado=true'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> list = data['data'] ?? [];
        if (mounted) {
          setState(() {
            _clientes = list.map((json) => ClientOption.fromJson(json)).toList();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showCustomToast(context, 'Error al cargar la lista de clientes', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingClientes = false;
        });
      }
    }
  }

  /// Alerta interactiva personalizada tipo Toast usando la API de Overlay de Flutter
  void _showCustomToast(BuildContext context, String message, {bool isError = false}) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16.0,
        left: 16.0,
        right: 16.0,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 250),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, (1 - value) * -15),
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              decoration: BoxDecoration(
                color: isError ? const Color(0xFFC62828) : AppTheme.deepRose,
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8.0,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    isError ? Icons.error_outline : Icons.check_circle_outline,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Auto-destrucción tras 2.8 segundos
    Future.delayed(const Duration(milliseconds: 2800), () {
      overlayEntry.remove();
    });
  }

  void _calculateGrandTotal() {
    double total = 0.0;
    for (var it in _addedItems) {
      total += it['subtotal'];
    }
    setState(() {
      _grandTotal = total;
    });
  }

  void _addItem() {
    if (_selectedProduct == null) {
      _showCustomToast(context, 'Por favor selecciona un producto', isError: true);
      return;
    }

    final int cant = int.tryParse(_cantidadController.text) ?? 1;
    if (cant <= 0) {
      _showCustomToast(context, 'La cantidad debe ser mayor a 0', isError: true);
      return;
    }

    if (cant > _selectedProduct!.stock) {
      _showCustomToast(context, 'Stock insuficiente para este producto', isError: true);
      return;
    }

    // Verificar si el producto ya fue añadido
    final existingIndex = _addedItems.indexWhere((it) => it['id_producto'].toString() == _selectedProduct!.id);
    
    if (existingIndex != -1) {
      final newCant = _addedItems[existingIndex]['cantidad'] + cant;
      if (newCant > _selectedProduct!.stock) {
        _showCustomToast(context, 'Supera el stock máximo disponible (${_selectedProduct!.stock})', isError: true);
        return;
      }
      setState(() {
        _addedItems[existingIndex]['cantidad'] = newCant;
        _addedItems[existingIndex]['subtotal'] = newCant * _selectedProduct!.precioVenta;
      });
    } else {
      setState(() {
        _addedItems.add({
          'id_producto': int.parse(_selectedProduct!.id),
          'nombre': _selectedProduct!.nombre,
          'precio_unitario': _selectedProduct!.precioVenta,
          'cantidad': cant,
          'subtotal': cant * _selectedProduct!.precioVenta,
        });
      });
    }

    _calculateGrandTotal();
    _showCustomToast(context, 'Producto añadido al resumen', isError: false);
    
    // Resetear formulario de producto
    setState(() {
      _selectedProduct = null;
      _cantidadController.text = '1';
    });
  }

  void _removeItem(int index) {
    final name = _addedItems[index]['nombre'];
    setState(() {
      _addedItems.removeAt(index);
    });
    _calculateGrandTotal();
    _showCustomToast(context, 'Removido: $name', isError: false);
  }

  Future<void> _submitPedido() async {
    if (!_formKey.currentState!.validate()) {
      _showCustomToast(context, 'Completa los campos obligatorios del envío', isError: true);
      return;
    }

    if (_selectedCliente == null) {
      _showCustomToast(context, 'Por favor selecciona un cliente', isError: true);
      return;
    }

    if (_addedItems.isEmpty) {
      _showCustomToast(context, 'Debes agregar al menos un producto al pedido', isError: true);
      return;
    }

    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final pedidoProv = Provider.of<PedidoProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.deepRose))),
    );

    final success = await pedidoProv.crearPedidoAdmin(
      token: authProv.token!,
      idCliente: _selectedCliente!.idUsuario,
      direccion: _direccionController.text.trim(),
      ciudad: _ciudadController.text.trim(),
      departamento: _departamentoController.text.trim(),
      metodoPago: _metodoPago,
      items: _addedItems.map((it) => {
        'id_producto': it['id_producto'],
        'cantidad': it['cantidad'],
      }).toList(),
    );

    if (mounted) {
      Navigator.pop(context); // Cerrar cargador

      if (success) {
        // Recargar pedidos del administrador
        await pedidoProv.cargarTodosLosPedidos(authProv.token!);
        
        if (mounted) {
          _showCustomToast(context, '¡Pedido creado con éxito!', isError: false);
          Navigator.pop(context); // Volver al panel anterior
        }
      } else {
        _showCustomToast(context, pedidoProv.errorMessage ?? 'Ocurrió un error al procesar el pedido.', isError: true);
      }
    }
  }

  @override
  void dispose() {
    _direccionController.dispose();
    _ciudadController.dispose();
    _departamentoController.dispose();
    _cantidadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productProv = Provider.of<ProductoProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Crear Pedido Directo"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _loadingClientes
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.deepRose)))
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // SECCIÓN 1: SELECCIÓN DE CLIENTE
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.person_search, color: AppTheme.deepRose),
                                  SizedBox(width: 8),
                                  Text("1. Buscar y Seleccionar Cliente", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Autocomplete<ClientOption>(
                                displayStringForOption: (ClientOption client) => '${client.fullName} (${client.email})',
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) {
                                    return const Iterable<ClientOption>.empty();
                                  }
                                  return _clientes.where((ClientOption client) {
                                    return client.fullName.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                                           client.email.toLowerCase().contains(textEditingValue.text.toLowerCase());
                                  });
                                },
                                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                  return TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: const InputDecoration(
                                      hintText: "Escribe nombre, apellido o correo electrónico...",
                                      prefixIcon: Icon(Icons.search),
                                    ),
                                  );
                                },
                                onSelected: (ClientOption selection) {
                                  setState(() {
                                    _selectedCliente = selection;
                                    _direccionController.text = selection.direccion ?? '';
                                    _ciudadController.text = selection.ciudad ?? '';
                                    _departamentoController.text = selection.departamento ?? '';
                                  });
                                },
                              ),
                              if (_selectedCliente != null) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.deepRose.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.deepRose.withOpacity(0.2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Cliente Seleccionado: ${_selectedCliente!.fullName}",
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.deepRose),
                                      ),
                                      Text("Email: ${_selectedCliente!.email}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // SECCIÓN 2: DATOS DE ENVÍO Y PAGO
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.local_shipping, color: AppTheme.deepRose),
                                  SizedBox(width: 8),
                                  Text("2. Dirección de Envío y Pago", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _direccionController,
                                autovalidateMode: AutovalidateMode.onUserInteraction,
                                maxLength: 30,
                                decoration: const InputDecoration(
                                  labelText: "Dirección de Envío *",
                                  counterText: "",
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'La dirección es obligatoria';
                                  if (val.trim().length < 3) return 'Mínimo 3 caracteres';
                                  if (val.trim().length > 30) return 'Máximo 30 caracteres';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _ciudadController,
                                      autovalidateMode: AutovalidateMode.onUserInteraction,
                                      maxLength: 50,
                                      decoration: const InputDecoration(
                                        labelText: "Ciudad *",
                                        counterText: "",
                                      ),
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) return 'La ciudad es obligatoria';
                                        if (val.trim().length < 3) return 'Mínimo 3 caracteres';
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _departamentoController,
                                      autovalidateMode: AutovalidateMode.onUserInteraction,
                                      maxLength: 50,
                                      decoration: const InputDecoration(
                                        labelText: "Departamento *",
                                        counterText: "",
                                      ),
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) return 'El departamento es obligatorio';
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: _metodoPago,
                                decoration: const InputDecoration(labelText: "Método de Pago *"),
                                items: const [
                                  DropdownMenuItem(value: 'efectivo', child: Text('Contra Entrega (Efectivo)')),
                                  DropdownMenuItem(value: 'transferencia', child: Text('Transferencia Bancaria')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _metodoPago = val;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // SECCIÓN 3: SELECCIÓN DE PRODUCTOS
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.add_shopping_cart, color: AppTheme.deepRose),
                                  SizedBox(width: 8),
                                  Text("3. Agregar Artículos", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Autocomplete<ProductModel>(
                                displayStringForOption: (ProductModel prod) => '${prod.nombre} - ${prod.marca} (${currencyFormatter.format(prod.precioVenta)})',
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) {
                                    return const Iterable<ProductModel>.empty();
                                  }
                                  return productProv.productos.where((ProductModel prod) {
                                    // REQUERIMIENTO: Ocultar productos sin stock disponible (stock == 0)
                                    return prod.stock > 0 && (
                                      prod.nombre.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                                      prod.marca.toLowerCase().contains(textEditingValue.text.toLowerCase())
                                    );
                                  });
                                },
                                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                  return TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: const InputDecoration(
                                      hintText: "Escribe nombre o marca del producto...",
                                      prefixIcon: Icon(Icons.search),
                                    ),
                                  );
                                },
                                onSelected: (ProductModel selection) {
                                  setState(() {
                                    _selectedProduct = selection;
                                    _cantidadController.text = '1';
                                  });
                                },
                              ),
                              if (_selectedProduct != null) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedProduct!.nombre,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text("Precio: ${currencyFormatter.format(_selectedProduct!.precioVenta)}", style: const TextStyle(color: AppTheme.deepRose, fontWeight: FontWeight.bold)),
                                          Text("Stock: ${_selectedProduct!.stock} unidades", style: TextStyle(color: _selectedProduct!.stock <= 5 ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          const Text("Cantidad:"),
                                          const SizedBox(width: 12),
                                          SizedBox(
                                            width: 80,
                                            height: 40,
                                            child: TextFormField(
                                              controller: _cantidadController,
                                              keyboardType: TextInputType.number,
                                              inputFormatters: [
                                                // REQUERIMIENTO: Evitar escribir signos menos, decimales o letras
                                                FilteringTextInputFormatter.digitsOnly,
                                              ],
                                              textAlign: TextAlign.center,
                                              decoration: const InputDecoration(
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                              onChanged: (val) {
                                                if (val.isEmpty) return;
                                                int? parsed = int.tryParse(val);
                                                
                                                // REQUERIMIENTO: Evitar negativos o cero
                                                if (parsed == null || parsed <= 0) {
                                                  _cantidadController.text = '1';
                                                  _cantidadController.selection = TextSelection.fromPosition(const TextPosition(offset: 1));
                                                  setState(() {});
                                                  _showCustomToast(context, 'La cantidad debe ser de al menos 1', isError: true);
                                                  return;
                                                }

                                                // REQUERIMIENTO: Si la cantidad supera el stock, igualar al stock máximo
                                                if (parsed > _selectedProduct!.stock) {
                                                  final maxStockStr = _selectedProduct!.stock.toString();
                                                  _cantidadController.text = maxStockStr;
                                                  _cantidadController.selection = TextSelection.fromPosition(
                                                    TextPosition(offset: maxStockStr.length)
                                                  );
                                                  setState(() {});
                                                  _showCustomToast(
                                                    context, 
                                                    'Ajustado automáticamente al stock máximo (${_selectedProduct!.stock})', 
                                                    isError: false
                                                  );
                                                } else {
                                                  setState(() {});
                                                }
                                              },
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            "Total: ${currencyFormatter.format(_selectedProduct!.precioVenta * (int.tryParse(_cantidadController.text) ?? 1))}",
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      ElevatedButton.icon(
                                        onPressed: _addItem,
                                        icon: const Icon(Icons.add),
                                        label: const Text("AÑADIR A LA LISTA"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.deepRose,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // SECCIÓN 4: DETALLE DE ARTÍCULOS AÑADIDOS
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.list_alt, color: AppTheme.deepRose),
                                  SizedBox(width: 8),
                                  Text("4. Resumen del Pedido", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_addedItems.isEmpty)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24.0),
                                    child: Text(
                                      "No has agregado ningún producto todavía.",
                                      style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                )
                              else
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _addedItems.length,
                                  itemBuilder: (context, index) {
                                    final item = _addedItems[index];
                                    return Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      decoration: BoxDecoration(
                                        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(item['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                const SizedBox(height: 2),
                                                Text(
                                                  "${item['cantidad']}x ${currencyFormatter.format(item['precio_unitario'])}",
                                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            currencyFormatter.format(item['subtotal']),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                            onPressed: () => _removeItem(index),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("TOTAL GENERAL:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(
                                    currencyFormatter.format(_grandTotal),
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.deepRose),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // BOTÓN FINAL DE REGISTRO
                      ElevatedButton(
                        onPressed: _submitPedido,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("CREAR PEDIDO ADMINISTRATIVO", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
